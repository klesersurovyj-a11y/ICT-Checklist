//
//  AssistantService.swift
//  ICT Checklist
//

import Foundation

enum AssistantError: LocalizedError {
    case missingKey
    case quota
    case network(String)
    case server(String)
    case emptyAnswer

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "Нужен ключ OpenAI (OPENAI_API_KEY) — без него ассистент не может ответить."
        case .quota:
            return "OpenAI вернул insufficient_quota: на ключе закончился баланс или квота. Это ограничение аккаунта OpenAI, а не приложения. Пополните баланс в Settings → Billing на platform.openai.com или создайте новый ключ в проекте с ненулевым балансом и вставьте его в приложение."
        case .network(let message):
            return message
        case .server(let message):
            return message
        case .emptyAnswer:
            return "Модель вернула пустой ответ. Попробуйте ещё раз."
        }
    }

    var needsBilling: Bool {
        if case .quota = self { return true }
        return false
    }
}

struct AssistantTurn {
    let role: String
    let text: String
}

enum AssistantService {
    static let model = "gpt-4o-mini"

    static let billingURL = URL(string: "https://platform.openai.com/settings/organization/billing/overview")!

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
            let info = apiError(data)

            if http.statusCode == 429 {
                if info.code == "insufficient_quota"
                    || info.message.localizedCaseInsensitiveContains("quota")
                    || info.message.localizedCaseInsensitiveContains("billing") {
                    throw AssistantError.quota
                }
                throw AssistantError.server(
                    "OpenAI: превышен лимит запросов. Подождите минуту и попробуйте снова."
                )
            }

            throw AssistantError.server(
                serverMessage(status: http.statusCode, detail: info.message)
            )
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

    private static func serverMessage(status: Int, detail: String) -> String {
        switch status {
        case 401:
            return "OpenAI не принял ключ. Проверьте значение OPENAI_API_KEY."
        case 403:
            return "OpenAI запретил запрос для этого ключа."
        case 400...499:
            return "OpenAI отклонил запрос. \(detail.isEmpty ? "Код \(status)." : detail)"
        default:
            return "OpenAI ответил ошибкой \(status). \(detail.isEmpty ? "Попробуйте позже." : detail)"
        }
    }
}
