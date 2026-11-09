import AppKit
@MainActor final class ApplicationDelegate:NSObject,NSApplicationDelegate {
    var composition:AppComposition?
    var terminating=false
    func applicationDidFinishLaunching(_ notification:Notification) {
        let others=NSRunningApplication.runningApplications(withBundleIdentifier:Bundle.main.bundleIdentifier ?? "com.decous.anysidebar.mac").filter{$0.processIdentifier != ProcessInfo.processInfo.processIdentifier}
        if let other=others.first{other.activate();NSApp.terminate(nil);return}
        Task{do{composition=try await AppComposition.make()}catch{let alert=NSAlert();alert.messageText="应用未能启动";alert.informativeText="本机数据或应用资源不可用。已有数据未清空，请检查构建或保存权限。";alert.runModal();NSApp.terminate(nil)}}
    }
    func applicationShouldTerminate(_ sender:NSApplication)->NSApplication.TerminateReply {
        if terminating{return .terminateNow};terminating=true
        Task{await composition?.shutdown();sender.reply(toApplicationShouldTerminate:true)}
        return .terminateLater
    }
    func applicationShouldHandleReopen(_ sender:NSApplication,hasVisibleWindows:Bool)->Bool{composition?.panel.show();return true}
}
@main struct AnySidebarMain {
    @MainActor static func main(){let app=NSApplication.shared;let delegate=ApplicationDelegate();app.delegate=delegate;app.setActivationPolicy(.accessory);withExtendedLifetime(delegate){app.run()}}
}
