import Foundation

struct TextAIRequest {
    let prompt: String
    let profileSummary: String
}

protocol TextAIProvider {
    func generate(request: TextAIRequest) async throws -> String
}
