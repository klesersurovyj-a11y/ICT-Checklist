//
//  AssistantService.swift
//  ICT Checklist
//

import Foundation

enum AssistantError: LocalizedError {
    case missingKey
    case network(String)
    case server(String)
    case emptyAnswer

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "Нужен ключ OpenAI (OPENAI_API_KEY) — без него ассистент не может ответить."
        case .network(let message):
            return message
        case .server(let message):
            return message
        case .emptyAnswer:
            return "Модель вернула пустой ответ. Попробуйте ещё раз."
        }
    }
}

struct AssistantTurn {
    let role: String
    let text: String
}

enum AssistantService {
    static let model = "gpt-4o-mini"

    private static let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    static func reply(system: String, history: [AssistantTurn], prompt: String) async throws -> String {
        guard let key = ApiKeyManager.shared.get(key: "OPENAI_API_KEY"), !key.isEmpty else {
            throw AssistantError.missingKey
        }

        var messages: [[String: String]] = [["role": "system", "content": system]]
        for turn in history.suffix(12) {
            messages.append(["role": turn.role, "content": turn.text])
        }
        messages.append(["role": "user", "content": prompt])

        let payload: [String: Any] = [
            "model": model,
            "temperature": 0.6,
            "max_tokens": 1200,
            "messages": messages
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AssistantError.network("Нет связи с OpenAI: \(error.localizedDescription)")
        }

        guard let http = response as? HTTPURLResponse else {
            throw AssistantError.network("Не удалось прочитать ответ OpenAI.")
        }

        guard (200..<300).contains(http.statusCode) else {
            throw AssistantError.server(serverMessage(status: http.statusCode, data: data))
        }

        struct ChatResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable {
                    let content: String?
                }
                let message: Message
            }
            let choices: [Choice]
        }

        let decoded: ChatResponse
        do {
            decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        } catch {
            throw AssistantError.network("Не удалось разобрать ответ OpenAI.")
        }

        let answer = decoded.choices.first?.message.content?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !answer.isEmpty else { throw AssistantError.emptyAnswer }
        return answer
    }

    private static func serverMessage(status: Int, data: Data) -> String {
        var detail = ""
        if
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let error = object["error"] as? [String: Any],
            let message = error["message"] as? String
        {
            detail = message
        }

        switch status {
        case 401:
            return "OpenAI не принял ключ. Проверьте значение OPENAI_API_KEY."
        case 403:
            return "OpenAI запретил запрос для этого ключа."
        case 429:
            return "OpenAI: превышен лимит запросов или закончилась квота."
        case 400...499:
            return "OpenAI отклонил запрос. \(detail.isEmpty ? "Код \(status)." : detail)"
        default:
            return "OpenAI ответил ошибкой \(status). \(detail.isEmpty ? "Попробуйте позже." : detail)"
        }
    }
}
