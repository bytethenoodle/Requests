#if os(Linux)
import Glibc
#else
import Darwin.C
#endif
import Nest
import Inquiline


enum HTTPParserError : Error {
    case Unknown
}

class HTTPParser {
  let socket: Socket

  init(socket: Socket) {
    self.socket = socket
  }

  // Read the socket until we find \r\n\r\n
  // returning string before and chars after
  func readUntil() throws -> (String, [CChar])? {
    var buffer: [CChar] = []

    while true {
      if let bytes = try? socket.read(bytes: 512) {
        if bytes.isEmpty {
          return nil
        }

        buffer += bytes

        let crln: [CChar] = [13, 10, 13, 10]
        if let (top, bottom) = buffer.find(characters: crln) {
          let headers = String(cString: top + [0])
          return (headers, bottom)
        }
      }
    }
  }

  func parse() throws -> Response {
    guard let (top, bodyPart) = try readUntil() else {
      throw HTTPParserError.Unknown
    }

    var components = top.split(separator: "\r\n")
    let requestLine = components.removeFirst()
    components.removeLast()
    let responseComponents = requestLine.split(separator: " ")
    if responseComponents.count < 3 {
      throw HTTPParserError.Unknown
    }

    let version = responseComponents[0]
    guard let statusCode = Int(responseComponents[1]) else {
      throw HTTPParserError.Unknown
    }
    //let statusReason = responseComponents[2]

    guard let status = Status(rawValue: statusCode) else {
      throw HTTPParserError.Unknown
    }

    if !version.hasPrefix("HTTP/1") {
      throw HTTPParserError.Unknown
    }

    let headers = parseHeaders(headers: components)
    let contentLength = Int(headers.filter { $0.0 == "Content-Length" }.first?.1 ?? "0") ?? 0

    var body: String? = nil

    if contentLength > 0 {
      var buffer = bodyPart
      var readLength = bodyPart.count

      while contentLength > readLength {
        let bytes = try socket.read(bytes: 2048)
        if bytes.isEmpty {
          throw HTTPParserError.Unknown // Server closed before sending complete body
        }
        buffer += bytes
        readLength += bytes.count
      }

      body = String(cString: buffer + [0])
    }

    return Response(status, headers: headers, content: body)
  }

  func parseHeaders(headers: [String]) -> [Header] {
    return headers.map { $0.split(separator: ":", maxSplit: 1) }.flatMap {
      if $0.count == 2 {
        if $0[1].characters.first == " " {
          let value = String($0[1].characters[$0[1].index(after: $0[1].startIndex)..<$0[1].endIndex])
          return ($0[0], value)
        }
        return ($0[0], $0[1])
      }

      return nil
    }
  }
}


extension Collection where Iterator.Element == CChar {
  func find(characters: [CChar]) -> ([CChar], [CChar])? {
    var lhs: [CChar] = []
    var rhs = Array(self)

    while !rhs.isEmpty {
      let character = rhs.remove(at: 0)
      lhs.append(character)
      if lhs.hasSuffix(characters: characters) {
        return (lhs, rhs)
      }
    }

    return nil
  }

  func hasSuffix(characters: [CChar]) -> Bool {
    let chars = Array(self)
    if chars.count >= characters.count {
      let index = chars.count - characters.count
      return Array(chars[index..<chars.count]) == characters
    }

    return false
  }
}

extension String {
  func hasPrefix(prefix: String) -> Bool {
    let characters = utf16
    let prefixCharacters = prefix.utf16

    if characters.count < prefixCharacters.count {
      return false
    }

    for idx in 0..<prefixCharacters.count {
        if characters[characters.index(characters.startIndex, offsetBy: idx)] != prefixCharacters[prefixCharacters.index(prefixCharacters.startIndex, offsetBy: idx)] {
            return false
        }
    }

    return true
  }
}
