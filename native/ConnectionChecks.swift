import Foundation
@main enum ConnectionChecks {
 static func main() {
  for value in ["http://127.0.0.1:18766","http://100.64.0.10:18766","http://100.127.255.254:18766","https://workbench.example.com"] {precondition(WorkbenchCredentials.acceptsBaseURL(value),value)}
  for value in ["http://100.1.2.3","http://100.128.0.1","http://100..64.0.1","http://example.com","https://user:pass@example.com","https://example.com/path","https://example.com?token=x","https://example.com#fragment","ftp://example.com"] {precondition(!WorkbenchCredentials.acceptsBaseURL(value),value)}
  print("PASS: configured origin boundaries and token destinations")
 }
}
