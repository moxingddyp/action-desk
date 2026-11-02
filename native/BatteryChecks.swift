import Foundation
@main enum BatteryChecks {
    static func main() throws {
        let sample=MacDeviceSampler().sample()
        guard let percent=sample.batteryPercent,let charging=sample.batteryCharging,let ac=sample.onACPower else {fatalError("IOKit battery fields missing")}
        precondition(percent>=0 && percent<=100)
        let data=try JSONSerialization.data(withJSONObject:["batteryPercent":percent,"batteryCharging":charging,"onACPower":ac],options:[.sortedKeys])
        print(String(decoding:data,as:UTF8.self))
    }
}
