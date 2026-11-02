import Foundation

enum WorkbenchRole { case mac, actions }
struct WorkbenchCredentials: Decodable {
    var baseURL: String
    var readToken: String
    var macToken: String
    var actionsToken: String
    static func privateHost(_ host:String)->Bool {
        let components=host.split(separator:".",omittingEmptySubsequences:false)
        guard components.count==4 else {return false}
        let parts=components.compactMap {Int($0)}
        return parts.count==4 && parts.allSatisfy {(0...255).contains($0)} && parts[0]==100 && (64...127).contains(parts[1])
    }
    static func acceptsBaseURL(_ value:String)->Bool {
        guard let url=URL(string:value), let host=url.host, !host.isEmpty, url.user==nil, url.password==nil, url.query==nil, url.fragment==nil, url.path.isEmpty else {return false}
        return url.scheme=="https" || (url.scheme=="http" && (host=="127.0.0.1" || privateHost(host)))
    }
    static func read() throws -> Self {
        let url=FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/CXY Action Desk OSS/client.json")
        let value=try JSONDecoder().decode(Self.self,from:Data(contentsOf:url))
        // HTTP is carried only inside the existing authenticated tailnet. ATS
        // permits this transport; reject unsupported origins before attaching tokens.
        guard Self.acceptsBaseURL(value.baseURL) else {throw URLError(.unsupportedURL)}
        return value
    }
}
private final class WorkbenchNoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping(URLRequest?)->Void) { completionHandler(nil) }
}
final class WorkbenchClient {
    private let session: URLSession
    init() {
        let configuration=URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest=3
        configuration.timeoutIntervalForResource=5
        configuration.connectionProxyDictionary = [:]
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpMaximumConnectionsPerHost=4
        session=URLSession(configuration:configuration,delegate:WorkbenchNoRedirect(),delegateQueue:nil)
    }
    func get<T:Decodable>(_ path:String,as type:T.Type,completion:@escaping(Result<T,Error>)->Void) {
        do {
            let credentials=try WorkbenchCredentials.read()
            guard let url=URL(string:credentials.baseURL+path) else {throw URLError(.badURL)}
            var request=URLRequest(url:url)
            request.setValue("Bearer "+credentials.readToken,forHTTPHeaderField:"Authorization")
            session.dataTask(with:request){data,response,error in
                if let error {completion(.failure(error));return}
                guard let response=response as? HTTPURLResponse,response.statusCode==200,let data,data.count<4_000_000 else {completion(.failure(URLError(.badServerResponse)));return}
                do {completion(.success(try JSONDecoder().decode(T.self,from:data)))}catch {completion(.failure(error))}
            }.resume()
        }catch {completion(.failure(error))}
    }
    func put<T:Encodable>(_ path:String,value:T,role:WorkbenchRole,completion:@escaping(Bool)->Void) {
        do {
            let credentials=try WorkbenchCredentials.read()
            guard let url=URL(string:credentials.baseURL+path) else {throw URLError(.badURL)}
            var request=URLRequest(url:url);request.httpMethod="PUT"
            request.setValue("Bearer "+(role == .mac ? credentials.macToken:credentials.actionsToken),forHTTPHeaderField:"Authorization")
            request.setValue("application/json",forHTTPHeaderField:"Content-Type")
            request.httpBody=try JSONEncoder().encode(value)
            session.dataTask(with:request){_,response,error in
                let code=(response as? HTTPURLResponse)?.statusCode ?? 0
                if let error { NSLog("Private service PUT %@ transport error %ld",path,(error as NSError).code) }
                else if !(200..<300).contains(code) {NSLog("Private service PUT %@ HTTP %ld",path,code)}
                completion(error==nil && (200..<300).contains(code))
            }.resume()
        }catch {completion(false)}
    }
}
