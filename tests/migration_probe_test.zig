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

// refAllDecls is SHALLOW — it references a namespace's top-level decls (types/consts)
// but does NOT analyze method BODIES, which Zig compiles lazily. The streaming
// subsystem (websocket/exec/attach/port-forward) once compiled "green" while its
// method bodies used removed 0.16 APIs, because nothing forced their analysis.
// Taking the address of each public method (`_ = &T.method`) forces full semantic
// analysis of its body, so a future API break fails the build here instead of in a
// downstream consumer. See brain: zig-refalldecls-false-confidence.
test "probe: streaming subsystem method bodies compile on 0.16" {
    const ws = klient.websocket;
    _ = &ws.WebSocketClient.init;
    _ = &ws.WebSocketClient.deinit;
    _ = &ws.WebSocketClient.connect;
    _ = &ws.WebSocketConnection.deinit;
    _ = &ws.WebSocketConnection.sendChannel;
    _ = &ws.WebSocketConnection.receive;
    _ = &ws.WebSocketConnection.close;
    _ = &ws.buildExecPath;
    _ = &ws.buildAttachPath;
    _ = &ws.buildPortForwardPath;

    _ = &klient.exec_mod.ExecClient.exec;
    _ = &klient.exec_mod.ExecClient.execSimple;
    _ = &klient.exec_mod.ExecResult.init;
    _ = &klient.exec_mod.ExecResult.deinit;
    _ = &klient.exec_mod.ExecSession.writeStdin;
    _ = &klient.exec_mod.ExecSession.read;
    _ = &klient.exec_mod.ExecSession.resize;

    _ = &klient.attach_mod.AttachClient.attach;
    _ = &klient.attach_mod.AttachSession.deinit;
    _ = &klient.attach_mod.AttachSession.writeStdin;
    _ = &klient.attach_mod.AttachSession.read;
    _ = &klient.attach_mod.AttachSession.resize;

    _ = &klient.port_forward_mod.PortForwarder.forward;
}

// JSON serialization paths that are lazily compiled and were also using removed
// 0.16 APIs (std.json.stringify free fn, ArrayList.writer) until fixed. Force them.
test "probe: JSON serialization paths compile on 0.16" {
    _ = &klient.auth.AccessReview.canI;
    _ = &klient.apply.StrategicMergePatch.build;
    _ = &klient.apply.JsonPatch.build;
    _ = &klient.apply.ApplyHelper.apply;
    _ = &klient.crd.DynamicClient.create;
    _ = &klient.crd.DynamicClient.update;
}

// Remaining public method bodies not exercised by other tests — force them so any
// further masked 0.16 breakage fails the build here.
test "probe: remaining module method bodies compile on 0.16" {
    _ = &klient.metrics.MetricsClient.getNodeMetrics;
    _ = &klient.metrics.MetricsClient.getAllPodMetrics;
    _ = &klient.metrics.MetricsClient.getPodMetrics;
    _ = &klient.metrics.MetricsClient.getPodMetricsByName;
    _ = &klient.exec_credential.executeCredentialPlugin;
    _ = &klient.exec_credential.awsEksConfig;
    _ = &klient.exec_credential.azureAksConfig;
    _ = &klient.incluster.loadInClusterConfig;
    _ = &klient.incluster.getServiceAccountToken;
    _ = &klient.incluster.getDefaultServer;
    _ = &klient.KubeconfigParser.load;
}
