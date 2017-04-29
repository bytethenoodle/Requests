import Nest
import Inquiline


public typealias Header = (String, String)


public enum RequestError : Error {
  case InvalidURL
  case UnsupportedScheme(String)
}


func createRequest(method: String, path: String, hostname: String, headers: [Header], body: String? = nil) -> RequestType {
  var requestsHeaders: [Header] = [("Host", hostname), ("Connection", "close")]

  if let body = body {
    requestsHeaders.append(("Content-Length", "\(body.utf8.count)"))
  }

  return Request(method: method, path: path, headers: requestsHeaders + headers, content: body)
}


func sendRequest(socket: Socket, request: RequestType) {
  socket.write(output: "\(request.method) \(request.path) HTTP/1.1\r\n")
  for (key, value) in request.headers {
    socket.write(output: "\(key): \(value)\r\n")
  }
  socket.write(output: "\r\n")

  if var body = request.body {
    while let chunk = body.next() {
        socket.write(output: chunk)
    }
  }
}


public func request(method method: String, url: String, headers: [Header]? = nil, body: String? = nil) throws -> Response {
  guard let url = URL(string: url) else {
    throw RequestError.InvalidURL
  }

  if url.scheme != "http" {
    throw RequestError.UnsupportedScheme(url.scheme)
  }

  let socket = try Socket()
  try socket.connect(hostname: url.hostname, port: url.port)
  let request = createRequest(method: method, path: url.path, hostname: url.hostname, headers: headers ?? [], body: body)
  sendRequest(socket: socket, request: request)

  let parser = HTTPParser(socket: socket)
  let response = try parser.parse()

  socket.close()

  return response
}
