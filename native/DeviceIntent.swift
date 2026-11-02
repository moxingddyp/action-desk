import AppIntents
import Foundation
import OSLog

struct DeviceDisplayAction: AppIntent {
    static var title:LocalizedStringResource="切换设备看板"
    static var openAppWhenRun=false
    static var isDiscoverable=false
    @Parameter(title:"操作") var action:String
    @Parameter(title:"选项") var value:String
    init(){}
    init(_ action:String,_ value:String){self.action=action;self.value=value}
    func perform()async throws->some IntentResult {
        let start = ProcessInfo.processInfo.systemUptime
        try DeviceDisplayPrefs.change(action,value)
        Logger(subsystem:"local.cxy.actiondesk",category:"interaction").notice("device action=\(action,privacy:.public) target=\(value,privacy:.public) handlerMs=\((ProcessInfo.processInfo.systemUptime-start)*1000,privacy:.public)")
        return .result()
    }
}
