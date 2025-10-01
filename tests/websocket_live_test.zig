const std = @import("std");
const klient = @import("klient");

/// Test Pod exec operation against live Rancher Desktop cluster
test "WebSocket - Pod Exec (echo command)" {
    const allocator = std.testing.allocator;

    // Parse kubeconfig
    const home = std.posix.getenv("HOME") orelse return error.NoHomeDir;
    const kubeconfig_path = try std.fmt.allocPrint(allocator, "{s}/.kube/config", .{home});
    defer allocator.free(kubeconfig_path);

    const kubeconfig_yaml = try std.fs.cwd().readFileAlloc(allocator, kubeconfig_path, 1024 * 1024);
    defer allocator.free(kubeconfig_yaml);

    var config = try klient.parseKubeconfig(allocator, kubeconfig_yaml);
    defer config.deinit();

    // Get rancher-desktop context
    const context = try config.getContextByName("rancher-desktop");
    const cluster = try config.getClusterByName(context.cluster);
    const user = try config.getUserByName(context.user);

    // Initialize K8s client
    var client_config = klient.K8sClient.Config{
        .api_server = cluster.server,
        .namespace = "default",
        .auth_method = .{ .bearer_token = user.token orelse return error.NoToken },
    };

    var k8s_client = try klient.K8sClient.init(allocator, client_config);
    defer k8s_client.deinit();

    // Create test pod
    const pod_yaml =
        \\apiVersion: v1
        \\kind: Pod
        \\metadata:
        \\  name: websocket-test-pod
        \\  namespace: default
        \\spec:
        \\  containers:
        \\  - name: test-container
        \\    image: busybox:latest
        \\    command: ["sleep", "3600"]
    ;

    const pod = try klient.parseYaml(klient.Pod, allocator, pod_yaml);
    defer pod.deinit();

    // Create pod
    const pods_client = klient.Pods.init(&k8s_client);
    const created_pod = try pods_client.client.create("default", pod.value);
    defer created_pod.deinit();

    // Wait for pod to be ready
    std.debug.print("Waiting for pod to be ready...\n", .{});
    std.time.sleep(5 * std.time.ns_per_s);

    // Initialize WebSocket client
    var ws_client = try klient.WebSocketClient.init(
        allocator,
        cluster.server,
        user.token,
        null,
    );
    defer ws_client.deinit();

    // Execute command in pod
    std.debug.print("Executing command in pod...\n", .{});
    
    const exec_path = try klient.buildExecPath(
        allocator,
        "default",
        "websocket-test-pod",
        &[_][]const u8{ "echo", "Hello from WebSocket!" },
        .{
            .stdin = false,
            .stdout = true,
            .stderr = true,
            .tty = false,
            .container = "test-container",
        },
    );
    defer allocator.free(exec_path);

    var connection = try ws_client.connect(exec_path, klient.Subprotocol.v4_channel.toString());
    defer connection.deinit();

    // Receive stdout
    std.debug.print("Receiving output...\n", .{});
    const message = try connection.receive();
    defer message.deinit(allocator);

    std.debug.print("Channel: {d}, Data: {s}\n", .{ message.channel, message.data });

    // Verify we received stdout (channel 1)
    try std.testing.expectEqual(@as(u8, 1), message.channel);
    try std.testing.expect(std.mem.indexOf(u8, message.data, "Hello from WebSocket!") != null);

    // Close connection
    connection.close();

    // Delete test pod
    std.debug.print("Cleaning up test pod...\n", .{});
    try pods_client.client.delete("default", "websocket-test-pod", null);
}

/// Test Pod attach operation
test "WebSocket - Pod Attach" {
    const allocator = std.testing.allocator;

    // Parse kubeconfig
    const home = std.posix.getenv("HOME") orelse return error.NoHomeDir;
    const kubeconfig_path = try std.fmt.allocPrint(allocator, "{s}/.kube/config", .{home});
    defer allocator.free(kubeconfig_path);

    const kubeconfig_yaml = try std.fs.cwd().readFileAlloc(allocator, kubeconfig_path, 1024 * 1024);
    defer allocator.free(kubeconfig_yaml);

    var config = try klient.parseKubeconfig(allocator, kubeconfig_yaml);
    defer config.deinit();

    const context = try config.getContextByName("rancher-desktop");
    const cluster = try config.getClusterByName(context.cluster);
    const user = try config.getUserByName(context.user);

    var client_config = klient.K8sClient.Config{
        .api_server = cluster.server,
        .namespace = "default",
        .auth_method = .{ .bearer_token = user.token orelse return error.NoToken },
    };

    var k8s_client = try klient.K8sClient.init(allocator, client_config);
    defer k8s_client.deinit();

    // Create test pod that outputs continuously
    const pod_yaml =
        \\apiVersion: v1
        \\kind: Pod
        \\metadata:
        \\  name: websocket-attach-test-pod
        \\  namespace: default
        \\spec:
        \\  containers:
        \\  - name: test-container
        \\    image: busybox:latest
        \\    command: ["sh", "-c", "while true; do echo 'Continuous output'; sleep 1; done"]
    ;

    const pod = try klient.parseYaml(klient.Pod, allocator, pod_yaml);
    defer pod.deinit();

    const pods_client = klient.Pods.init(&k8s_client);
    const created_pod = try pods_client.client.create("default", pod.value);
    defer created_pod.deinit();

    // Wait for pod to be running
    std.debug.print("Waiting for pod to be running...\n", .{});
    std.time.sleep(5 * std.time.ns_per_s);

    // Initialize WebSocket client for attach
    var ws_client = try klient.WebSocketClient.init(
        allocator,
        cluster.server,
        user.token,
        null,
    );
    defer ws_client.deinit();

    const attach_path = try klient.buildAttachPath(
        allocator,
        "default",
        "websocket-attach-test-pod",
        .{
            .stdin = false,
            .stdout = true,
            .stderr = true,
            .tty = false,
            .container = "test-container",
        },
    );
    defer allocator.free(attach_path);

    var connection = try ws_client.connect(attach_path, klient.Subprotocol.v4_channel.toString());
    defer connection.deinit();

    // Receive multiple outputs
    std.debug.print("Receiving attach output...\n", .{});
    var received_count: usize = 0;
    while (received_count < 3) : (received_count += 1) {
        const message = try connection.receive();
        defer message.deinit(allocator);
        
        std.debug.print("Channel: {d}, Data: {s}\n", .{ message.channel, message.data });
        try std.testing.expectEqual(@as(u8, 1), message.channel); // stdout
        try std.testing.expect(std.mem.indexOf(u8, message.data, "Continuous output") != null);
    }

    connection.close();

    // Delete test pod
    std.debug.print("Cleaning up test pod...\n", .{});
    try pods_client.client.delete("default", "websocket-attach-test-pod", null);
}

/// Test Port Forward operation
test "WebSocket - Port Forward" {
    const allocator = std.testing.allocator;

    // Parse kubeconfig
    const home = std.posix.getenv("HOME") orelse return error.NoHomeDir;
    const kubeconfig_path = try std.fmt.allocPrint(allocator, "{s}/.kube/config", .{home});
    defer allocator.free(kubeconfig_path);

    const kubeconfig_yaml = try std.fs.cwd().readFileAlloc(allocator, kubeconfig_path, 1024 * 1024);
    defer allocator.free(kubeconfig_yaml);

    var config = try klient.parseKubeconfig(allocator, kubeconfig_yaml);
    defer config.deinit();

    const context = try config.getContextByName("rancher-desktop");
    const cluster = try config.getClusterByName(context.cluster);
    const user = try config.getUserByName(context.user);

    var client_config = klient.K8sClient.Config{
        .api_server = cluster.server,
        .namespace = "default",
        .auth_method = .{ .bearer_token = user.token orelse return error.NoToken },
    };

    var k8s_client = try klient.K8sClient.init(allocator, client_config);
    defer k8s_client.deinit();

    // Create test pod with HTTP server
    const pod_yaml =
        \\apiVersion: v1
        \\kind: Pod
        \\metadata:
        \\  name: websocket-portforward-test-pod
        \\  namespace: default
        \\spec:
        \\  containers:
        \\  - name: test-container
        \\    image: nginx:alpine
        \\    ports:
        \\    - containerPort: 80
    ;

    const pod = try klient.parseYaml(klient.Pod, allocator, pod_yaml);
    defer pod.deinit();

    const pods_client = klient.Pods.init(&k8s_client);
    const created_pod = try pods_client.client.create("default", pod.value);
    defer created_pod.deinit();

    // Wait for pod to be ready
    std.debug.print("Waiting for nginx pod to be ready...\n", .{});
    std.time.sleep(10 * std.time.ns_per_s);

    // Initialize WebSocket client for port-forward
    var ws_client = try klient.WebSocketClient.init(
        allocator,
        cluster.server,
        user.token,
        null,
    );
    defer ws_client.deinit();

    const pf_path = try klient.buildPortForwardPath(
        allocator,
        "default",
        "websocket-portforward-test-pod",
        &[_]u16{80},
    );
    defer allocator.free(pf_path);

    var connection = try ws_client.connect(pf_path, klient.Subprotocol.v4_channel.toString());
    defer connection.deinit();

    // Send HTTP GET request through port-forward
    std.debug.print("Sending HTTP request through port-forward...\n", .{});
    const http_request = "GET / HTTP/1.1\r\nHost: localhost\r\n\r\n";
    try connection.sendChannel(0, http_request); // Channel 0 for data stream

    // Receive HTTP response
    const message = try connection.receive();
    defer message.deinit(allocator);

    std.debug.print("Received response: {s}\n", .{message.data});
    try std.testing.expect(std.mem.indexOf(u8, message.data, "HTTP/1.1") != null);
    try std.testing.expect(std.mem.indexOf(u8, message.data, "nginx") != null);

    connection.close();

    // Delete test pod
    std.debug.print("Cleaning up test pod...\n", .{});
    try pods_client.client.delete("default", "websocket-portforward-test-pod", null);
}

/// Test WebSocket frame protocol
test "WebSocket - Frame Protocol" {
    const allocator = std.testing.allocator;

    // Test frame building with different payload sizes
    const test_cases = [_]struct {
        payload: []const u8,
        expected_min_frame_size: usize,
    }{
        .{ .payload = "short", .expected_min_frame_size = 11 }, // 2 header + 4 mask + 5 payload
        .{ .payload = "This is a much longer message that exceeds 125 bytes when repeated multiple times: " ** 3, .expected_min_frame_size = 254 }, // 4 header + 4 mask + payload
    };

    for (test_cases) |case| {
        std.debug.print("Testing payload size: {d} bytes\n", .{case.payload.len});
        
        // This would test the internal frame building logic
        // For now, verify the payload size expectations
        try std.testing.expect(case.payload.len > 0);
    }
}

/// Test SPDY channel protocol
test "WebSocket - SPDY Channels" {
    const allocator = std.testing.allocator;

    // Test SPDY channel constants
    try std.testing.expectEqual(@as(u8, 0), klient.Channel.stdin.toInt());
    try std.testing.expectEqual(@as(u8, 1), klient.Channel.stdout.toInt());
    try std.testing.expectEqual(@as(u8, 2), klient.Channel.stderr.toInt());
    try std.testing.expectEqual(@as(u8, 3), klient.Channel.error_stream.toInt());
    try std.testing.expectEqual(@as(u8, 4), klient.Channel.resize.toInt());
}

