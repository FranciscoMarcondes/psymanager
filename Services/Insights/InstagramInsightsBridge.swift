import Foundation

struct InsightSnapshotDTO: Decodable {
    let periodLabel: String
    let periodStartISO: String
    let periodEndISO: String
    let followersStart: Int
    let followersEnd: Int
    let reach: Int
    let impressions: Int
    let profileVisits: Int
    let reelViews: Int
    let postsPublished: Int
}

enum InstagramInsightsBridge {
    static func sync(baseURL: String, artistHandle: String) async throws -> [InsightSnapshotDTO] {
        let normalizedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let encodedHandle = artistHandle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(normalizedBaseURL)/instagram/insights?artist=\(encodedHandle)")
        else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode([InsightSnapshotDTO].self, from: data)
    }
}