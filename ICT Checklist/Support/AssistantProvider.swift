//
//  AssistantProvider.swift
//  ICT Checklist
//
//  Провайдеры ИИ-ассистента: OpenAI и OpenRouter.
//  У каждого свой ключ, свой адрес API и свой список моделей.
//

import Foundation

enum AssistantProvider: String, CaseIterable, Identifiable {
    case openAI = "openai"
    case openRouter = "openrouter"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openAI: return "OpenAI"
        case .openRouter: return "OpenRouter"
        }
    }

    var subtitle: String {
        switch self {
        case .openAI: return "Прямой доступ к моделям OpenAI"
        case .openRouter: return "Один ключ на модели OpenAI, Anthropic, Google и DeepSeek"
        }
    }

    var keyName: String {
        switch self {
        case .openAI: return "OPENAI_API_KEY"
        case .openRouter: return "OPENROUTER_API_KEY"
        }
    }

    var chatEndpoint: URL {
        switch self {
        case .openAI:
            return URL(string: "https://api.openai.com/v1/chat/completions")!
        case .openRouter:
            return URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        }
    }

    /// Где создать ключ.
    var keyURL: URL {
        switch self {
        case .openAI:
            return URL(string: "https://platform.openai.com/api-keys")!
        case .openRouter:
            return URL(string: "https://openrouter.ai/keys")!
        }
    }

    /// Где пополнить баланс.
    var billingURL: URL {
        switch self {
        case .openAI:
            return URL(string: "https://platform.openai.com/settings/organization/billing/overview")!
        case .openRouter:
            return URL(string: "https://openrouter.ai/credits")!
        }
    }

    var models: [String] {
        switch self {
        case .openAI:
            return ["gpt-4o-mini", "gpt-4o", "gpt-4.1-mini", "gpt-4.1"]
        case .openRouter:
            return [
                "openai/gpt-4o-mini",
                "openai/gpt-4o",
                "anthropic/claude-3.5-sonnet",
                "google/gemini-2.0-flash-001",
                "deepseek/deepseek-chat",
                "meta-llama/llama-3.3-70b-instruct"
            ]
        }
    }

    var defaultModel: String { models[0] }

    var other: AssistantProvider {
        self == .openAI ? .openRouter : .openAI
    }
}
