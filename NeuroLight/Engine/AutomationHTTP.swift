// ========== BLOCK 19: AutomationHTTP - START ==========
//
//  AutomationHTTP.swift
//  NeuroLight
//
//  Minimal HTTP/1.1 request parser and response builder. No external
//  dependency. Sufficient for our local control layer; not a general
//  HTTP server.
//
//  DEBUG only.
//

#if DEBUG

import Foundation

struct HTTPRequest {
    let method: String
    let path: String
    let query: [String: String]
    let headers: [String: String]
    let body: Data

    var bodyString: String {
        String(data: body, encoding: .utf8) ?? ""
    }

    var bodyJSON: [String: Any]? {
        guard !body.isEmpty,
              let obj = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            return nil
        }
        return obj
    }

    /// Returns the parsed request and the number of bytes consumed.
    /// Returns nil when the buffer doesn't yet contain a full request.
    static func parse(_ data: Data) -> (HTTPRequest, Int)? {
        guard let headerEnd = data.range(of: Data([0x0d, 0x0a, 0x0d, 0x0a])) else {
            return nil
        }
        let headerData = data.subdata(in: 0..<headerEnd.lowerBound)
        guard let headerString = String(data: headerData, encoding: .utf8) else { return nil }

        let lines = headerString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }

        let parts = requestLine.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count >= 2 else { return nil }
        let method = String(parts[0])
        let rawTarget = String(parts[1])

        let (path, query) = splitPathAndQuery(rawTarget)

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            if let colon = line.firstIndex(of: ":") {
                let key = line[..<colon].lowercased()
                var value = String(line[line.index(after: colon)...])
                if value.first == " " { value.removeFirst() }
                headers[String(key)] = value
            }
        }

        let bodyStart = headerEnd.upperBound
        let contentLength = Int(headers["content-length"] ?? "0") ?? 0
        let bodyEnd = bodyStart + contentLength
        guard data.count >= bodyEnd else { return nil }
        let body = data.subdata(in: bodyStart..<bodyEnd)

        let req = HTTPRequest(method: method, path: path, query: query, headers: headers, body: body)
        return (req, bodyEnd)
    }

    private static func splitPathAndQuery(_ raw: String) -> (String, [String: String]) {
        guard let q = raw.firstIndex(of: "?") else { return (raw, [:]) }
        let path = String(raw[..<q])
        let queryString = raw[raw.index(after: q)...]
        var query: [String: String] = [:]
        for pair in queryString.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let key = String(kv[0]).removingPercentEncoding ?? String(kv[0])
            let value = kv.count > 1 ? (String(kv[1]).removingPercentEncoding ?? String(kv[1])) : ""
            query[key] = value
        }
        return (path, query)
    }
}

struct HTTPResponse {
    let status: Int
    let reason: String
    let headers: [String: String]
    let body: Data

    static func json(_ object: Any, status: Int = 200) -> HTTPResponse {
        let data = (try? JSONSerialization.data(withJSONObject: object,
                                                options: [.sortedKeys, .prettyPrinted])) ?? Data()
        return HTTPResponse(
            status: status,
            reason: reasonFor(status),
            headers: ["Content-Type": "application/json; charset=utf-8"],
            body: data
        )
    }

    static func text(_ string: String, status: Int = 200) -> HTTPResponse {
        HTTPResponse(
            status: status,
            reason: reasonFor(status),
            headers: ["Content-Type": "text/plain; charset=utf-8"],
            body: Data(string.utf8)
        )
    }

    static func png(_ data: Data) -> HTTPResponse {
        HTTPResponse(
            status: 200,
            reason: "OK",
            headers: ["Content-Type": "image/png"],
            body: data
        )
    }

    static let notFound = HTTPResponse.json(["error": "not found"], status: 404)
    static let badRequest = HTTPResponse.json(["error": "bad request"], status: 400)

    func serialize() -> Data {
        var head = "HTTP/1.1 \(status) \(reason)\r\n"
        head += "Content-Length: \(body.count)\r\n"
        head += "Connection: close\r\n"
        for (k, v) in headers {
            head += "\(k): \(v)\r\n"
        }
        head += "\r\n"
        var data = Data(head.utf8)
        data.append(body)
        return data
    }

    private static func reasonFor(_ code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 400: return "Bad Request"
        case 404: return "Not Found"
        case 500: return "Internal Server Error"
        default:  return "OK"
        }
    }
}

#endif
// ========== BLOCK 19: AutomationHTTP - END ==========
