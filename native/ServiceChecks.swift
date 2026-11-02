// Standalone integration check of the live private backend, not compiled into Apps.
import Foundation
@main enum ServiceChecks {
    static func main() {
        let client=WorkbenchClient();var count=0;var errors=[String]()
        client.get("/v1/actions",as:Snapshot.self){result in
            DispatchQueue.main.async {
                switch result {
                case .success(let value):
                    if value.items.isEmpty || value.sourceRevision.count != 64 {errors.append("Invalid action snapshot")}
                    print("Actions decoded, items=\(value.items.count), activityEvidence=\(value.activityEvidence?.count ?? 0)")
                case .failure(let error):errors.append("Actions: "+String(describing:error))
                };count+=1
            }
        }
        client.get("/v1/telemetry",as:TelemetrySnapshot.self){result in
            DispatchQueue.main.async {
                switch result {
                case .success(let value):
                    if Set(value.devices.map(\.id)) != Set(["mac","winpc","linux"]) {errors.append("Device identities mismatch")}
                    for device in value.devices {
                        let age=device.receivedAt.map{Date().timeIntervalSince($0)} ?? .infinity
                        if age < -2 {errors.append("Invalid timestamp epoch for "+device.id)}
                        print("Device \(device.id), age=\(Int(min(99999,age))), fresh=\(device.fresh())")
                    }
                case .failure(let error):errors.append("Telemetry: "+String(describing:error))
                };count+=1
            }
        }
        let deadline=Date().addingTimeInterval(12)
        while count<2 && Date()<deadline {RunLoop.main.run(until:Date().addingTimeInterval(0.05))}
        if count != 2 {errors.append("Request did not terminate within bound")}
        precondition(errors.isEmpty,errors.joined(separator:"; "))
        print("PASS: authenticated API, decoder contracts, identities and timestamp epoch")
    }
}
