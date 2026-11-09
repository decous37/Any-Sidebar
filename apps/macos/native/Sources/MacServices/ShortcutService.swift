import AppKit
@preconcurrency import Carbon
import ReadingCore
private func hotkeyHandler(_ next:EventHandlerCallRef?,_ event:EventRef?,_ context:UnsafeMutableRawPointer?) -> OSStatus {
    guard let context else{return OSStatus(eventNotHandledErr)}
    let service=Unmanaged<ShortcutService>.fromOpaque(context).takeUnretainedValue()
    Task{@MainActor in service.fire()};return noErr
}
@MainActor public final class ShortcutService {
    private var hotkey:EventHotKeyRef?
    private var handler:EventHandlerRef?
    private var monitor:Any?
    private var recording:ID?
    public private(set) var binding:ShortcutBinding?
    public private(set) var state="unbound"
    public var triggered: (() -> Void)?
    public var recorded: ((ID,ShortcutBinding?) -> Void)?
    public init() {
        var spec=EventTypeSpec(eventClass:OSType(kEventClassKeyboard),eventKind:UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(),hotkeyHandler,1,&spec,Unmanaged.passUnretained(self).toOpaque(),&handler)
    }
    public func fire() {if recording==nil{triggered?()}}
    private func register(_ binding:ShortcutBinding) throws -> EventHotKeyRef {
        guard (0...127).contains(binding.keyCode),!binding.modifiers.isEmpty,Set(binding.modifiers).isSubset(of:["command","option","control","shift"]),binding.modifiers.contains("command") || binding.modifiers.contains("control") || binding.modifiers.contains("option") else{throw AppFault("INVALID_ARGUMENT","快捷键至少包含 Command、Option 或 Control。")}
        var modifiers:UInt32=0
        for modifier in binding.modifiers {modifiers |= UInt32(modifier=="command" ? cmdKey:modifier=="option" ? optionKey:modifier=="control" ? controlKey:shiftKey)}
        var result:EventHotKeyRef?
        let status=RegisterEventHotKey(UInt32(binding.keyCode),modifiers,EventHotKeyID(signature:0x4153424D,id:1),GetApplicationEventTarget(),0,&result)
        guard status==noErr,let result else{throw AppFault("SHORTCUT_CONFLICT","此快捷键已被占用，请选择其他组合。")};return result
    }
    public func replace(_ proposed:ShortcutBinding?,persist:() async throws -> Void) async throws {
        if proposed==binding {try await persist();return}
        let candidate=try proposed.map{try register($0)}
        do {try await persist()} catch {if let candidate{UnregisterEventHotKey(candidate)};throw error}
        if let hotkey{UnregisterEventHotKey(hotkey)};hotkey=candidate;binding=proposed;state=proposed==nil ? "unbound":"active"
    }
    public func restore(_ proposed:ShortcutBinding?) {
        guard let proposed else{return}
        do{hotkey=try register(proposed);binding=proposed;state="active"}catch{state="conflict"}
    }
    public func startRecording(id:ID) {
        cancelRecording();recording=id
        monitor=NSEvent.addLocalMonitorForEvents(matching:.keyDown){[weak self] event in
            guard let self,self.recording==id else{return event}
            if event.keyCode==53 {self.cancelRecording();self.recorded?(id,nil);return nil}
            var mods:[String]=[]
            for (flag,name):(NSEvent.ModifierFlags,String) in [(.command,"command"),(.option,"option"),(.control,"control"),(.shift,"shift")] {if event.modifierFlags.contains(flag){mods.append(name)}}
            if mods.isEmpty{return nil}
            let value=ShortcutBinding(keyCode:Int(event.keyCode),modifiers:mods);self.cancelRecording();self.recorded?(id,value);return nil
        }
    }
    public func cancelRecording() {if let monitor{NSEvent.removeMonitor(monitor)};monitor=nil;recording=nil}
    public func stop() {cancelRecording();if let hotkey{UnregisterEventHotKey(hotkey)};hotkey=nil;if let handler{RemoveEventHandler(handler)};handler=nil}
}
