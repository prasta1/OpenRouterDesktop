import Foundation

struct OpenRouterModel: Identifiable, Codable {
    let id: String
    let name: String
    let provider: String?
    let contextLength: Int?
    let pricing: Pricing?
    
    var displayName: String {
        if let provider = provider {
            return "\(name) (\(provider))"
        }
        return name
    }
    
    var isFree: Bool {
        guard let pricing = pricing else { return false }
        return pricing.prompt == 0 && pricing.completion == 0
    }

    var family: String {
        let components = id.components(separatedBy: "/")
        return components.first ?? "Other"
    }

    /// Human-readable price line like "$3.00 / $15.00 per 1M" or "Free" or nil if pricing unknown.
    /// OpenRouter quotes per-token; we multiply by 1M for readability.
    var priceDescription: String? {
        guard let pricing else { return nil }
        if isFree { return "Free" }
        let promptPer1M = pricing.prompt * 1_000_000
        let completionPer1M = pricing.completion * 1_000_000
        return "$\(Self.formatPrice(promptPer1M)) / $\(Self.formatPrice(completionPer1M)) per 1M"
    }

    private static func formatPrice(_ value: Double) -> String {
        if value >= 1 {
            return String(format: "%.2f", value)
        }
        // sub-dollar prices (e.g. $0.05/M) deserve more precision
        return String(format: "%.3f", value)
    }

    struct Pricing: Codable, Equatable {
        let prompt: Double
        let completion: Double
        
        enum CodingKeys: String, CodingKey {
            case prompt
            case completion
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            if let promptDouble = try? container.decode(Double.self, forKey: .prompt) {
                prompt = promptDouble
            } else if let promptString = try? container.decode(String.self, forKey: .prompt) {
                prompt = Double(promptString) ?? 0
            } else {
                prompt = 0
            }
            
            if let completionDouble = try? container.decode(Double.self, forKey: .completion) {
                completion = completionDouble
            } else if let completionString = try? container.decode(String.self, forKey: .completion) {
                completion = Double(completionString) ?? 0
            } else {
                completion = 0
            }
        }
    }
}

struct ModelsResponse: Codable {
    let data: [ModelData]
    
    struct ModelData: Codable {
        let id: String
        let name: String?
        let provider: Provider?
        let contextLength: Int?
        let pricing: OpenRouterModel.Pricing?
        
        struct Provider: Codable {
            let name: String
        }
        
        func toOpenRouterModel() -> OpenRouterModel {
            OpenRouterModel(
                id: id,
                name: name ?? id,
                provider: provider?.name,
                contextLength: contextLength,
                pricing: pricing
            )
        }
    }
}