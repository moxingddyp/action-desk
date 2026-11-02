import Foundation
@main enum TelemetryChecks {
 static func main() throws {
  let now=Date();var s=DeviceSample(id:"linux",host:"example-linux",receivedAt:now)
  precondition(s.fresh(at:now.addingTimeInterval(11)))
  precondition(!s.fresh(at:now.addingTimeInterval(13)))
  s.issue="disconnected";precondition(!s.fresh(at:now))
  let raw=Data("{\"id\":\"winpc\",\"host\":\"Example PC\",\"cpu\":0,\"gpu\":null,\"memoryUsed\":1024,\"memoryTotal\":2048}".utf8)
  let decoded=try JSONDecoder().decode(DeviceSample.self,from:raw)
  precondition(decoded.cpu==0 && decoded.gpu==nil)
  let snapshot=TelemetryStore.read()!
  precondition(Set(snapshot.devices.map(\.id))==Set(["mac","winpc","linux"]))
  for d in snapshot.devices {
   precondition(d.fresh(at:now),"No fresh sample for "+d.id)
   precondition(d.cpu != nil && d.cpu!>=0 && d.cpu!<=100)
   precondition(d.memoryUsed!>=0 && d.memoryUsed!<=d.memoryTotal!)
   precondition(d.disks!.allSatisfy{$0.used>=0 && $0.used <= $0.total})
   precondition(d.download != nil && d.upload != nil)
  }
  print("PASS: all three installed-app live streams, metric bounds, counter-null distinction, stale/disconnect handling")
 }
}
