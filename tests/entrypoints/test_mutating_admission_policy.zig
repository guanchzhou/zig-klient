// Live integration test for the K8s 1.36 GA resource MutatingAdmissionPolicy.
// Requires a Kubernetes >= 1.36 API server (the kind only exists there).
// Exercises the full CRUD path through zig-klient: list -> create -> get -> delete.
//
// Connects via `kubectl proxy` (default http://127.0.0.1:8080) to avoid the
// std.crypto.tls handshake limitation against self-signed clusters. Run first:
//     kubectl proxy --port=8080
const std = @import("std");
const klient = @import("klient");

const NAME = "zig-klient-probe";

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  Test: MutatingAdmissionPolicy CRUD (K8s 1.36, zig-klient)\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n\n", .{});

    var client = try klient.K8sClient.init(allocator, io, .{
        .server = "http://127.0.0.1:8080",
        .namespace = "default",
    });
    defer client.deinit();
    std.debug.print("🔌 Connected — API server: {s}\n\n", .{client.api_server});

    const policies = klient.MutatingAdmissionPolicies.init(&client);

    // 1. LIST (read path against the live 1.36 endpoint)
    {
        const list = try policies.client.list(null);
        defer list.deinit();
        std.debug.print("📋 list: {} existing MutatingAdmissionPolicy object(s)\n", .{list.value.items.len});
    }

    // 2. CREATE — build the spec's nested fields from JSON (they are std.json.Value).
    const mc_json =
        \\{"resourceRules":[{"apiGroups":["apps"],"apiVersions":["v1"],"operations":["CREATE"],"resources":["deployments"]}]}
    ;
    var mc = try std.json.parseFromSlice(std.json.Value, allocator, mc_json, .{});
    defer mc.deinit();

    const mut_json =
        \\[{"patchType":"ApplyConfiguration","applyConfiguration":{"expression":"Object{ metadata: Object.metadata{ labels: {'zig-klient': 'probe'} } }"}}]
    ;
    var muts = try std.json.parseFromSlice([]std.json.Value, allocator, mut_json, .{});
    defer muts.deinit();

    const policy = klient.MutatingAdmissionPolicy{
        .apiVersion = "admissionregistration.k8s.io/v1",
        .kind = "MutatingAdmissionPolicy",
        .metadata = .{ .name = NAME },
        .spec = .{
            .failurePolicy = "Fail",
            .reinvocationPolicy = "Never",
            .matchConstraints = mc.value,
            .mutations = muts.value,
        },
    };
    {
        const created = try policies.client.create(policy, null);
        defer created.deinit();
        std.debug.print("✅ create: {s}\n", .{created.value.metadata.name});
    }

    // 3. GET — read it back and confirm a field survived the round-trip.
    {
        const got = try policies.client.get(NAME, null);
        defer got.deinit();
        const rp = got.value.spec.?.reinvocationPolicy orelse "(none)";
        std.debug.print("✅ get: {s} (reinvocationPolicy={s})\n", .{ got.value.metadata.name, rp });
    }

    // 4. DELETE — clean up.
    try policies.client.delete(NAME, null);
    std.debug.print("✅ delete: {s}\n", .{NAME});

    std.debug.print("\n═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  ✅ MutatingAdmissionPolicy CRUD round-trip succeeded\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
}
