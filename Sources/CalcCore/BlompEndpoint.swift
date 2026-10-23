import Foundation

public enum BlompEndpoint {
    /// Blomp's catalog may advertise legacy HTTP. Only its known HTTPS host is
    /// usable; never follow the advertised HTTP URL or relax certificate checks.
    public static func storage(_ advertised: String) throws -> URL {
        guard var url = URLComponents(string: advertised),
              ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
              ["swiftproxy.acs.ai.net", "swiftproxy.blomp.com"].contains(url.host?.lowercased() ?? ""),
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.path.hasPrefix("/v1/AUTH_"), url.path.count > 9, url.path.dropFirst(9).allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }),
              [nil, 443, 8080, 80].contains(url.port) else { throw CloudError.unsafeEndpoint }
        url.scheme = "https"; url.port = nil
        guard let result = url.url else { throw CloudError.unsafeEndpoint }
        return result
    }
    public static func object(base: URL, container: String, path: String) throws -> URL {
        guard !container.isEmpty, container != ".", container != "..", container.utf8.count <= 320, !container.contains("/"), !container.contains("\\"),
              !container.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
              path.hasPrefix("c84/v1/"), path.count < 512,
              path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." && $0.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || [45,46,95].contains($0) }) }) else { throw CloudError.unsafeEndpoint }
        return base.appendingPathComponent(container).appendingPathComponent(path)
    }
}
