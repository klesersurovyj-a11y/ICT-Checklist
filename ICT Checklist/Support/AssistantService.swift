//
//  AssistantService.swift
//  ICT Checklist
//

import Foundation

enum AssistantError: LocalizedError {
    case missingKey(AssistantProvider)
    case quota(AssistantProvider)
    case network(AssistantProvider, String)
    case server(AssistantProvider, String)
    case emptyAnswer

    var errorDescription: String? {
        switch self {
        case .missingKey(let provider):
            return "Нужен ключ \(provider.title) (\(provider.keyName)) — без него ассистент не может ответить. Добавьте его в настройках ключей приложения."
        case .quota(let provider):
            return "\(provider.title) вернул ошибку квоты: на ключе закончился баланс или лимит. Это ограничение аккаунта \(provider.title), а не приложения. Пополните баланс или переключитесь на второго провайдера — история чата сохранится."
        case .network(let provider, let message):
            return message.isEmpty
                ? "Нет связи с \(provider.title)."
                : "Нет связи с \(provider.title): \(message)"
        case .server(_, let message):
            return message
        case .emptyAnswer:
            return "Модель вернула пустой ответ. Попробуйте ещё раз."
        }
    }

    var needsBilling: Bool {
        if case .quota = self { return true }
        return false
    }

    /// Провайдер, у которого закончилась квота, — чтобы предложить второго.
    var quotaProvider: AssistantProvider? {
        if case .quota(let provider) = self { return provider }
        return nil
    }

    var isMissingKey: Bool {
        if case .missingKey = self { return true }
        return false
    }
}

struct AssistantTurn {
    let role: String
    let text: String
}

struct AssistantReply {
    let text: String
    let provider: AssistantProvider
    let model: String
    let cost: Double?
}

enum AssistantService {
    static func reply(
        provider: AssistantProvider,
        model: String,
        system: String,
        history: [AssistantTurn],
        prompt: String
    ) async throws -> AssistantReply {
        let key = (ApiKeyManager.shared.get(key: provider.keyName) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !key.isEmpty else {
            throw AssistantError.missingKey(provider)
        }

        var messages: [[String: String]] = [["role": "system", "content": system]]
        for turn in history.suffix(12) {
            messages.append(["role": turn.role, "content": turn.text])
        }
        messages.append(["role": "user", "content": prompt])

        var payload: [String: Any] = [
            "model": model,
            "temperature": 0.6,
            "max_tokens": 1200,
            "messages": messages
        ]

        // OpenRouter присылает стоимость ответа в usage.cost.
        if provider == .openRouter {
            payload["usage"] = ["include": true]
        }

        var request = URLRequest(url: provider.chatEndpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        if provider == .openRouter {
            request.setValue("ICT Checklist", forHTTPHeaderField: "X-Title")
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AssistantError.network(provider, error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AssistantError.network(provider, "не удалось прочитать ответ.")
        }

        let info = apiError(data)

        guard (200..<300).contains(http.statusCode) else {
            if isQuota(status: http.statusCode, info: info) {
                throw AssistantError.quota(provider)
            }

            if http.statusCode == 429 {
                throw AssistantError.server(
                    provider,
                    "\(provider.title): превышен лимит запросов. Подождите минуту и попробуйте снова."
                )
            }

            throw AssistantError.server(
                provider,
                serverMessage(provider: provider, status: http.statusCode, detail: info.message)
            )
        }

        struct ChatResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable {
                    let content: String?
                }
                let message: Message
            }
            struct Usage: Decodable {
                let cost: Double?
                let totalCost: Double?

                enum CodingKeys: String, CodingKey {
                    case cost
                    case totalCost = "total_cost"
                }
            }
            let choices: [Choice]
            let usage: Usage?
        }

        let decoded: ChatResponse
        do {
            decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        } catch {
            throw AssistantError.network(provider, "не удалось разобрать ответ.")
        }

        let answer = decoded.choices.first?.message.content?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !answer.isEmpty else { throw AssistantError.emptyAnswer }

        return AssistantReply(
            text: answer,
            provider: provider,
            model: model,
            cost: decoded.usage?.cost ?? decoded.usage?.totalCost
        )
    }

    // MARK: - Errors

    private static func isQuota(status: Int, info: (code: String, message: String)) -> Bool {
        if status == 402 { return true }

        guard status == 429 || status == 403 else { return false }

        let text = info.message.lowercased()
        return info.code == "insufficient_quota"
            || text.contains("quota")
            || text.contains("billing")
            || text.contains("credit")
    }

    private static func apiError(_ data: Data) -> (code: String, message: String) {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let error = object["error"] as? [String: Any]
        else {
            return ("", "")
        }
        return (
            error["code"] as? String ?? "",
            error["message"] as? String ?? ""
        )
    }

    private static func serverMessage(
        provider: AssistantProvider,
        status: Int,
        detail: String
    ) -> String {
        switch status {
        case 401:
            return "\(provider.title) не принял ключ. Проверьте значение \(provider.keyName)."
        case 403:
            return "\(provider.title) запретил запрос для этого ключа."
        case 400...499:
            return "\(provider.title) отклонил запрос. \(detail.isEmpty ? "Код \(status)." : detail)"
        default:
            return "\(provider.title) ответил ошибкой \(status). \(detail.isEmpty ? "Попробуйте позже." : detail)"
        }
    }
}
