import Vapor

struct SmartSortRequest: Content {
    let text: String
    let userExamples: String?
}

struct AIAnalysisResult: Content {
    let folders: [String]
    let deadline: String?
    let price: Double?
}

struct SmartSortController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.post("smart-sort", use: smartSort)
    }

    func smartSort(req: Request) async throws -> AIAnalysisResult {
        _ = try req.auth.require(User.self)

        guard let apiKey = Environment.get("OPENAI_API_KEY"), !apiKey.isEmpty else {
            throw Abort(.internalServerError, reason: "OPENAI_API_KEY not set on server.")
        }

        let input = try req.content.decode(SmartSortRequest.self)

        let systemPrompt = """
        You are a smart filing assistant. Analyze the input text/URL and categorize it.

        Rules:
        1. Extract relevant TOPICS as folders.
        2. Identify DEADLINES (format: YYYY-MM-DD).
        3. Identify PRICE if present (number only).
        4. Return STRICT JSON with keys: folders (array of strings), deadline (string or null), price (number or null).

        \( (input.userExamples ?? "").isEmpty ? "" : "Here is how the user previously organized similar items:\n" + (input.userExamples ?? "") )
        """

        // Use a Codable struct instead of [String: Any]
        struct OpenAIRequest: Content {
            let model: String
            let response_format: ResponseFormat
            let messages: [Message]
            
            struct ResponseFormat: Content {
                let type: String
            }
            
            struct Message: Content {
                let role: String
                let content: String
            }
        }

        let requestBody = OpenAIRequest(
            model: "gpt-5-mini",
            response_format: OpenAIRequest.ResponseFormat(type: "json_object"),
            messages: [
                OpenAIRequest.Message(role: "system", content: systemPrompt),
                OpenAIRequest.Message(role: "user", content: input.text)
            ]
        )

        let res = try await req.client.post(
            URI(string: "https://api.openai.com/v1/chat/completions"),
            beforeSend: { r in
                r.headers.bearerAuthorization = BearerAuthorization(token: apiKey)
                r.headers.contentType = .json
                try r.content.encode(requestBody)
            }
        )

        struct OpenAIChoice: Decodable {
            struct Msg: Decodable { let content: String? }
            let message: Msg
        }
        struct OpenAIResponse: Decodable { let choices: [OpenAIChoice] }

        let decoded = try res.content.decode(OpenAIResponse.self)
        guard let jsonString = decoded.choices.first?.message.content,
              let data = jsonString.data(using: .utf8) else {
            throw Abort(.badGateway, reason: "OpenAI response missing JSON content.")
        }

        return try JSONDecoder().decode(AIAnalysisResult.self, from: data)
    }
}
