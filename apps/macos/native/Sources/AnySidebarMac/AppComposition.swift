import AppKit
import WebKit
import ReadingCore
import ReadingStorage
import MacServices
import DeepSeekTransport
@MainActor final class EventRelay {var update:((String)->Void)?}
@MainActor final class AppComposition {
    let resources:ApplicationResources
    let runtime:ReadingRuntime
    let store:FileAttachmentStore
    let vault:KeychainVault
    let selection=AccessibilitySelectionService()
    let screen=ScreenCaptureService()
    let shortcut=ShortcutService()
    let companion=CompanionController()
    var panel:ConversationPanelController!
    var captureJob:Task<Void,Never>?
    var captureOperation:ID?
    var captureError:AppFault?
    var recordingOperation:ID?
    var recordedShortcut:ShortcutBinding?
    var selectionStatus="disabled"
    var workspaceObserver:Any?
    var mouseMonitor:Any?
    let relay:EventRelay
    static func make() async throws -> AppComposition {
        guard let resourceRoot=Bundle.main.resourceURL else{throw AppFault("RESOURCE_MISSING","应用资源缺失。")}
        let resources=try ApplicationResources(root:resourceRoot)
        let dataRoot=try FileManager.default.url(for:.applicationSupportDirectory,in:.userDomainMask,appropriateFor:nil,create:true).appendingPathComponent("com.decous.anysidebar.mac")
        let relay=EventRelay(),vault=KeychainVault(),transport=RequestCoordinator(vault:KeychainVault())
        let (store,runtime)=try await Task.detached {
            let database=try SQLiteDatabase(directory:dataRoot),store=try FileAttachmentStore(root:dataRoot)
            let runtime=try ReadingRuntime(repository:database,assets:store,transport:transport,catalog:resources.catalog,prompt:resources.prompt,changed:{type in Task{@MainActor in relay.update?(type)}})
            return (store,runtime)
        }.value
        return AppComposition(resources:resources,runtime:runtime,store:store,vault:vault,relay:relay)
    }
    init(resources:ApplicationResources,runtime:ReadingRuntime,store:FileAttachmentStore,vault:KeychainVault,relay:EventRelay){
        self.resources=resources;self.runtime=runtime;self.store=store;self.vault=vault;self.relay=relay
        panel=ConversationPanelController(resources:resources,composition:self)
        relay.update={[weak self] type in self?.panel.bridge.event(type);Task{await self?.refresh()}}
        companion.opened={[weak self] in self?.panel.show()}
        companion.captured={[weak self] in Task{await self?.captureCurrent()}}
        companion.quit={NSApp.terminate(nil)}
        selection.receive={[weak self] event in Task{@MainActor in
            guard let self else{return}
            do{let id=try await runtime.ingestSelection(event);if case .selected(let token,_,_)=event.outcome{self.selection.acknowledge(token:token,quoteId:id)}}catch{self.selectionStatus="unsupported"}
        }}
        selection.status={[weak self] value in Task{@MainActor in self?.selectionStatus=value}}
        shortcut.triggered={[weak self] in Task{await self?.captureCurrent()}}
        shortcut.recorded={[weak self] id,binding in guard let self,self.recordingOperation==id else{return};self.recordedShortcut=binding;self.recordingOperation=nil;self.panel.bridge.event("shortcut-recording-changed")}
        workspaceObserver=NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.didActivateApplicationNotification,object:nil,queue:.main){[weak self] notification in
            guard let app=notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else{return}
            Task{@MainActor in self?.selection.activate(app);await self?.refresh()}
        }
        mouseMonitor=NSEvent.addGlobalMonitorForEvents(matching:.leftMouseUp){[weak self] _ in Task{@MainActor in self?.selection.scheduleRead()}}
        Task {let p=await runtime.preferences();shortcut.restore(p.captureShortcut);companion.show(p.companionVisible);await refresh();panel.show();try? await runtime.garbageCollect()}
    }
    func refresh() async {
        let p=await runtime.preferences(),route=await runtime.route(),permissions=PermissionService.state()
        selection.configure(enabled:p.autoSelectionEnabled && p.disclosureVersion=="v1" && permissions["accessibility"]==true,taskId:route.0,epoch:route.1)
        if p.autoSelectionEnabled,let app=NSWorkspace.shared.frontmostApplication,app.bundleIdentifier != Bundle.main.bundleIdentifier {selection.activate(app)}
        if let view=try? await runtime.view(),let draft=view.currentTask?.draft {companion.reference(!draft.externalQuotes.isEmpty || !draft.images.isEmpty || draft.assistantQuote != nil)}
    }
    func bootstrap() async throws -> JSONValue {
        let credential:JSONValue
        do{credential = .object(["state":.string("known"),"configured":.bool(try await vault.configured())])}
        catch{credential = .object(["state":.string("unknown"),"error":try .encode(AppFault("CREDENTIAL_ACCESS_DENIED","暂时无法检查钥匙串，请检查系统授权。",retryable:true))])}
        return .object(["runtime":try .encode(await runtime.view()),"permissions":try .encode(PermissionService.state()),"credential":credential,"shortcutState":.string(shortcut.state),"recordingOperationId":recordingOperation.map(JSONValue.string) ?? .null,"recordedShortcut":try .encode(recordedShortcut),"captureOperationId":captureOperation.map(JSONValue.string) ?? .null,"captureError":try .encode(captureError),"selectionStatus":.string(selectionStatus)])
    }
    func captureCurrent() async {if let id = (await runtime.route()).0 {do{try await startCapture(taskId:id,mode:"region",operationId:newID())}catch{captureError=(error as? AppFault)}}}
    func startCapture(taskId:ID,mode:String,operationId:ID) async throws {
        guard captureOperation==nil else{throw AppFault("CAPTURE_BUSY","已有截图操作正在进行。")}
        let p=await runtime.preferences()
        guard p.disclosureVersion=="v1" else{throw AppFault("CONSENT_REQUIRED","请先在设置中确认采集说明。")}
        _=try await runtime.view(taskId:taskId)
        captureOperation=operationId;captureError=nil
        panel.hide();companion.show(false)
        captureJob=Task {
            defer{captureOperation=nil;captureJob=nil;companion.show(p.companionVisible);panel.bridge.event("capture-changed")}
            do{
                let (png,source)=try await screen.capture(mode:mode);try Task.checkCancellation()
                let store=self.store
                let asset=try await Task.detached{try store.persist(png:png,source:source)}.value
                try Task.checkCancellation();try await runtime.attachCapture(asset,taskId:taskId)
                panel.show()
            }catch{
                captureError=(error as? AppFault) ?? AppFault("CAPTURE_FAILED","截图失败，请检查屏幕访问权限后重试。",retryable:true)
                if captureError?.code != "CAPTURE_CANCELLED" {panel.show()}
            }
        }
    }
    func dispatch(_ request:BridgeRequest) async throws -> JSONValue {
        let c=request.command,a=request.args,op=request.operationId
        func str(_ key:String)->String{a[key]?.string ?? ""}
        func int(_ key:String)->Int{a[key]?.int ?? -1}
        let reads:Set<String>=["bootstrap","listTasks","getTaskView","getOperation","getCredentialStatus"]
        if c=="getOperation" {return try .encode(await runtime.operation(str("sourceOperationId")))}
        if c=="getTaskView" {return .object(["runtime":try .encode(await runtime.view(taskId:str("taskId"),cursor:a["cursor"]?.int))])}
        if c=="listTasks" {return try .encode(await runtime.view().tasks)}
        if !reads.contains(c) {
            let digest=c=="setKey" ? "sensitive":FileAttachmentStore.digest(try JSONEncoder().encode(JSONValue.object(a)))
            if try await !runtime.reserveOperation(op,command:c,digest:digest) {
                if let previous=await runtime.operation(op),previous.state=="failed",let error=previous.error {throw error}
                return try await bootstrap()
            }
        }
        do {
            var resultID:ID?
            switch c {
            case "bootstrap","getCredentialStatus":break
            case "createTask":resultID=try await runtime.createTask(title:str("title"))
            case "switchTask":try await runtime.switchTask(str("taskId"))
            case "renameTask":try await runtime.renameTask(str("taskId"),title:str("title"),expected:int("expectedRevision"))
            case "changeDraft":try await runtime.changeDraft(taskId:str("taskId"),expected:int("expectedRevision"),change:a["change"]!.object!)
            case "send":resultID=try await runtime.send(taskId:str("taskId"),expectedDraft:int("expectedDraftRevision"),expectedPreferences:int("expectedPreferencesRevision"),operationId:op)
            case "retry","regenerate":resultID=try await runtime.replay(taskId:str("taskId"),turnId:str("turnId"),requestId:str("requestId"),kind:c,expectedPreferences:int("expectedPreferencesRevision"),operationId:op)
            case "stop":
                let t=a["target"]!.object!
                if t["kind"]?.string=="request",Set(t.keys)==["kind","taskId","requestId"],let tid=t["taskId"]?.string,let rid=t["requestId"]?.string,validID(tid),validID(rid) {try await runtime.stop(.request(taskId:tid,requestId:rid))}
                else if t["kind"]?.string=="operation",Set(t.keys)==["kind","taskId","sourceOperationId"],let tid=t["taskId"]?.string,let source=t["sourceOperationId"]?.string,validID(tid),validID(source) {try await runtime.stop(.operation(taskId:tid,sourceOperationId:source))}
                else{throw AppFault("INVALID_ARGUMENT","停止目标无效。")}
            case "restoreSubmission":try await runtime.restoreSubmission(taskId:str("taskId"),requestId:str("requestId"),expected:int("expectedDraftRevision"))
            case "savePreferences":
                let patch=a["patch"]!.object!
                if let raw=patch["captureShortcut"] {
                    guard patch.count==1 else{throw AppFault("INVALID_ARGUMENT","请单独设置快捷键。")}
                    let binding=raw == .null ? nil:try raw.decode(ShortcutBinding.self)
                    guard int("expectedRevision") == (await runtime.preferences()).revision else{throw AppFault("REVISION_CONFLICT","设置已更新，请重试。")}
                    try await shortcut.replace(binding){try await self.runtime.setShortcut(binding)}
                }else{try await runtime.savePreferences(expected:int("expectedRevision"),patch:patch)}
            case "setKey":try await vault.replace(str("key"))
            case "clearKey":try await vault.clear()
            case "acceptDisclosure":try await runtime.acceptDisclosure()
            case "setAutoSelectionEnabled":try await runtime.enableSelection(a["enabled"]!.bool!,expected:int("expectedRevision"));await refresh()
            case "requestPermission":PermissionService.request(str("kind"));await refresh()
            case "startCapture":try await startCapture(taskId:str("taskId"),mode:str("mode"),operationId:op)
            case "cancelCapture":if captureOperation==str("captureOperationId"){screen.overlay.cancel();captureJob?.cancel()}
            case "startShortcutRecording":recordingOperation=op;recordedShortcut=nil;shortcut.startRecording(id:op)
            case "cancelShortcutRecording":if recordingOperation==str("recordingOperationId"){shortcut.cancelRecording();recordingOperation=nil}
            case "deleteTask":try await runtime.deleteTask(str("taskId"),expected:int("expectedRevision"))
            case "clearAllTasks":try await runtime.clearAllTasks()
            case "setCompanionVisible":let visible=a["visible"]!.bool!;try await runtime.companionVisible(visible);companion.show(visible)
            case "copyText":NSPasteboard.general.clearContents();guard NSPasteboard.general.setString(str("text"),forType:.string) else{throw AppFault("COPY_FAILED","复制失败，请重试。")}
            default:throw AppFault("INVALID_ARGUMENT","未知操作。")
            }
            if !reads.contains(c){try await runtime.finishOperation(op,resultId:resultID)}
            return try await bootstrap()
        }catch{
            let fault=(error as? AppFault) ?? AppFault("STORAGE_FAILED","操作未完成，已保存的数据会保留。",retryable:true)
            if !reads.contains(c){try? await runtime.finishOperation(op,error:fault)}
            throw fault
        }
    }
    func shutdown() async {captureJob?.cancel();screen.overlay.cancel();shortcut.stop();selection.configure(enabled:false,taskId:nil,epoch:0);if let mouseMonitor{NSEvent.removeMonitor(mouseMonitor)};await runtime.shutdown()}
}
