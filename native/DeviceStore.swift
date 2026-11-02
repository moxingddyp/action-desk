import Foundation
import Darwin

enum DeviceStore {
    // Foundation's home is the extension container when WidgetKit is sandboxed.
    // Resolve the account home so host and extension use the one entitled cache.
    static let accountHome: URL = {
        guard let account=getpwuid(getuid()),let home=account.pointee.pw_dir else {
            preconditionFailure("Cannot resolve current macOS account home")
        }
        return URL(fileURLWithPath:String(cString:home),isDirectory:true)
    }()
    static let directory=accountHome.appendingPathComponent("Library/Application Support/CXY Device Dashboard OSS",isDirectory:true)
    static let preferenceDirectory=directory.appendingPathComponent("Preferences",isDirectory:true)
    static func link(_ action:String,_ value:String)->URL {
        var components=URLComponents();components.scheme="cxy-devices-oss";components.host=action;components.path="/"+value
        return components.url!
    }
}
