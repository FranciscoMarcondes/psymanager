import Foundation

struct OpenAITextProvider: TextAIProvider {
    private let apiKey: String
    private let model: String

    init(apiKey: String, model: String = "gpt-4.1-mini") {
        self.apiKey = apiKey
        self.model = model
    }

    func generate(request: TextAIRequest) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw AIProviderError.invalidURL
        }

        let systemPrompt = """
        Voce e um manager de carreira para DJs de psytrance. Seja pratico, objetivo e orientado a acao. Sempre entregue proximo passo claro.
        """

        let body = OpenAIChatRequest(
            model: model,
            temperature: 0.7,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: "Contexto do artista: \(request.profileSummary)"),
                .init(role: "user", content: request.prompt),
            ]
        )

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw AIProviderError.requestFailed
        }

        let decoded = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content, !content.isEmpty else {
            throw AIProviderError.emptyResponse
        }
        return content
    }
}

enum AIProviderError: Error {
    case invalidURL
    case requestFailed
    case emptyResponse
}

private struct OpenAIChatRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let temperature: Double
    let messages: [Message]
}

private struct OpenAIChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let role: String
            let content: String
        }

        let message: Message
    }

    let choices: [Choice]
}
