// Forces compilation of code paths that are lazy-evaluated by the rest of the
// test suite, so 0.16 regressions in rarely-reached functions surface here
// instead of in downstream consumers.
//
// 0.16 note: std.testing.refAllDeclsRecursive was removed. We walk the module
// tree manually by importing each sub-namespace and calling refAllDecls on it.
const std = @import("std");
const klient = @import("klient");

test "probe: entire klient surface compiles" {
    std.testing.refAllDecls(klient);
    std.testing.refAllDecls(klient.types);
    std.testing.refAllDecls(klient.resources);
    std.testing.refAllDecls(klient.retry);
    std.testing.refAllDecls(klient.watch);
    std.testing.refAllDecls(klient.tls);
    std.testing.refAllDecls(klient.pool);
    std.testing.refAllDecls(klient.crd);
    std.testing.refAllDecls(klient.exec_credential);
    std.testing.refAllDecls(klient.incluster);
    std.testing.refAllDecls(klient.list_options);
    std.testing.refAllDecls(klient.delete_options);
    std.testing.refAllDecls(klient.apply);
    std.testing.refAllDecls(klient.websocket);
    std.testing.refAllDecls(klient.exec_mod);
    std.testing.refAllDecls(klient.attach_mod);
    std.testing.refAllDecls(klient.port_forward_mod);
    std.testing.refAllDecls(klient.metrics);
    std.testing.refAllDecls(klient.auth);
    std.testing.refAllDecls(klient.proxy_fallback);
}

test "probe: generic Informer(T) and Watcher(T) instantiate" {
    const InformerT = klient.Informer(klient.types.Pod);
    std.testing.refAllDecls(InformerT);
    _ = &InformerT.init;
    _ = &InformerT.deinit;
    _ = &InformerT.start;
    _ = &InformerT.stop;

    const WatcherT = klient.Watcher(klient.types.Pod);
    std.testing.refAllDecls(WatcherT);
}

test "probe: ResourceClient(T) instantiates" {
    const RC = klient.ResourceClient(klient.types.Pod);
    std.testing.refAllDecls(RC);
}
