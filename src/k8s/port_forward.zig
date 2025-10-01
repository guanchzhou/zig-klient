const std = @import("std");
const ws = @import("websocket_client.zig");

/// Pod port-forward client for forwarding local ports to pod ports
pub const PortForwarder = struct {
    allocator: std.mem.Allocator,
    ws_client: *ws.WebSocketClient,

    pub fn init(allocator: std.mem.Allocator, ws_client: *ws.WebSocketClient) PortForwarder {
        return PortForwarder{
            .allocator = allocator,
            .ws_client = ws_client,
        };
    }

    /// Start port forwarding to a pod
    pub fn forward(
        self: *PortForwarder,
        pod_name: []const u8,
        namespace: []const u8,
        options: PortForwardOptions,
    ) !ForwardSession {
        // Extract remote ports
        var remote_ports = try self.allocator.alloc(u16, options.ports.len);
        defer self.allocator.free(remote_ports);

        for (options.ports, 0..) |mapping, i| {
            remote_ports[i] = mapping.remote;
        }

        // Build WebSocket path
        const path = try ws.buildPortForwardPath(
            self.allocator,
            namespace,
            pod_name,
            remote_ports,
        );
        defer self.allocator.free(path);

        // Connect via WebSocket
        const conn = try self.allocator.create(ws.WebSocketConnection);
        errdefer self.allocator.destroy(conn);

        conn.* = try self.ws_client.connect(path, ws.Subprotocol.v4_channel.toString());

        // Create port mappings
        const mappings = try self.allocator.dupe(PortMapping, options.ports);
        errdefer self.allocator.free(mappings);

        return ForwardSession{
            .allocator = self.allocator,
            .conn = conn,
            .ports = mappings,
            .active = true,
        };
    }
};

/// Options for port-forward operation
pub const PortForwardOptions = struct {
    /// Port mappings (local -> remote)
    ports: []const PortMapping,
};

/// Port mapping configuration
pub const PortMapping = struct {
    /// Local port to listen on
    local: u16,

    /// Remote port in the pod
    remote: u16,
};

/// Active port-forward session
pub const ForwardSession = struct {
    allocator: std.mem.Allocator,
    conn: *ws.WebSocketConnection,
    ports: []const PortMapping,
    active: bool,

    pub fn deinit(self: *ForwardSession) void {
        self.stop();
        self.conn.deinit();
        self.allocator.destroy(self.conn);
        self.allocator.free(self.ports);
    }

    /// Stop port forwarding
    pub fn stop(self: *ForwardSession) void {
        if (self.active) {
            self.conn.close();
            self.active = false;
        }
    }

    /// Check if session is still active
    pub fn isActive(self: *ForwardSession) bool {
        return self.active and self.conn.connected;
    }

    /// Get port mappings
    pub fn getPorts(self: *ForwardSession) []const PortMapping {
        return self.ports;
    }

    /// Forward data from local to remote port
    pub fn forwardToRemote(self: *ForwardSession, port_index: usize, data: []const u8) !void {
        if (!self.active) return error.SessionClosed;
        if (port_index >= self.ports.len) return error.InvalidPortIndex;

        // Port-forward uses SPDY channels
        // Even channels (0, 2, 4, ...) are data channels
        // Odd channels (1, 3, 5, ...) are error channels
        const channel: u8 = @intCast(port_index * 2);

        try self.conn.sendChannel(channel, data);
    }

    /// Receive data from remote port
    pub fn receiveFromRemote(self: *ForwardSession) !PortMessage {
        if (!self.active) return error.SessionClosed;

        const msg = try self.conn.receive();

        // Determine port index from channel
        const port_index: usize = msg.channel / 2;
        const is_error = msg.channel % 2 == 1;

        return PortMessage{
            .port_index = port_index,
            .port = if (port_index < self.ports.len) self.ports[port_index] else PortMapping{ .local = 0, .remote = 0 },
            .data = msg.data,
            .is_error = is_error,
        };
    }
};

/// Message from a forwarded port
pub const PortMessage = struct {
    /// Index into the ports array
    port_index: usize,

    /// Port mapping
    port: PortMapping,

    /// Data received
    data: []const u8,

    /// True if this is an error message
    is_error: bool,

    pub fn deinit(self: PortMessage, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }
};
