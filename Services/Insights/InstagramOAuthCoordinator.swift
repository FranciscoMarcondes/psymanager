import Foundation

struct InstagramOAuthCoordinator {
    static let callbackScheme = "psymanager"
    static let callbackHost = "oauth"
    static let callbackPath = "/instagram"

    static func startURL(baseURL: String, artistHandle: String) -> URL? {
        let normalizedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let encodedHandle = artistHandle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedRedirect = callbackURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(normalizedBaseURL)/auth/instagram/start?artist=\(encodedHandle)&redirect_uri=\(encodedRedirect)")
        else {
            return nil
        }
        return url
    }

    static var callbackURL: URL {
        URL(string: "\(callbackScheme)://\(callbackHost)\(callbackPath)")!
    }

    static func parseCallback(_ url: URL) -> (status: String?, handle: String?, errorDescription: String?)? {
        guard url.scheme == callbackScheme, url.host == callbackHost, url.path == callbackPath else {
            return nil
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let status = components?.queryItems?.first(where: { $0.name == "status" })?.value
        let handle = components?.queryItems?.first(where: { $0.name == "handle" })?.value
        let errorDescription = components?.queryItems?.first(where: { $0.name == "error_description" })?.value
        return (status, handle, errorDescription)
    }
}
