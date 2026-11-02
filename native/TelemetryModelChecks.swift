import Foundation
@main enum TelemetryModelChecks {
 static func main() throws {
  let now=Date();var sample=DeviceSample(id:"linux",host:"example",receivedAt:now)
  precondition(sample.fresh(at:now.addingTimeInterval(11)))
  precondition(!sample.fresh(at:now.addingTimeInterval(13)))
  sample.issue="disconnected";precondition(!sample.fresh(at:now))
  let raw=Data("{\"id\":\"winpc\",\"host\":\"example\",\"cpu\":0,\"gpu\":null,\"memoryUsed\":1024,\"memoryTotal\":2048}".utf8)
  let decoded=try JSONDecoder().decode(DeviceSample.self,from:raw)
  precondition(decoded.cpu==0 && decoded.gpu==nil)
  let packet=TelemetrySnapshot(generatedAt:now,devices:[decoded])
  let roundtrip=try JSONDecoder().decode(TelemetrySnapshot.self,from:JSONEncoder().encode(packet))
  precondition(roundtrip.devices.count==1 && roundtrip.devices[0].cpu==0)
  print("PASS: synthetic telemetry epoch, null-vs-zero and staleness models; no live cache read")
 }
}
