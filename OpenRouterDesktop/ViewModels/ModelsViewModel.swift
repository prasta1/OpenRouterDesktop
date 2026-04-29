import Foundation
import SwiftUI

@MainActor
final class ModelsViewModel: ObservableObject {
    @Published var models: [OpenRouterModel] = [] {
        didSet { freeModels = models.filter { $0.isFree } }
    }
    @Published var selectedModel: OpenRouterModel?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var searchText: String = ""

    /// When true, only models priced at $0/$0 are shown. Persisted to UserDefaults.
    /// Defaults to true on first launch since OpenRouter's free tier is the most common case.
    @Published var freeOnly: Bool {
        didSet { UserDefaults.standard.set(freeOnly, forKey: PreferenceKeys.freeModelsOnly) }
    }

    @Published private(set) var freeModels: [OpenRouterModel] = []

    private let service = OpenRouterService.shared

    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: PreferenceKeys.freeModelsOnly) == nil {
            self.freeOnly = true
        } else {
            self.freeOnly = defaults.bool(forKey: PreferenceKeys.freeModelsOnly)
        }
    }

    private var sourceModels: [OpenRouterModel] {
        freeOnly ? freeModels : models
    }

    var filteredModels: [OpenRouterModel] {
        let source = sourceModels
        guard !searchText.isEmpty else { return source }
        return source.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.id.localizedCaseInsensitiveContains(searchText) ||
            ($0.provider?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var freeModelsCount: Int { freeModels.count }

    var groupedModels: [(family: String, models: [OpenRouterModel])] {
        let grouped = Dictionary(grouping: filteredModels) { $0.family }
        return grouped
            .map { (family: $0.key, models: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.family < $1.family }
    }

    func fetchModels() async {
        guard !isLoading else { return }
        guard KeychainService.shared.hasAPIKey else {
            errorMessage = "No API key configured. Please add your API key in Settings."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            models = try await service.fetchModels()
            if selectedModel == nil, let firstModel = models.first {
                selectedModel = firstModel
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func selectModel(_ model: OpenRouterModel) {
        selectedModel = model
        UserDefaults.standard.set(model.id, forKey: PreferenceKeys.selectedModelId)
    }

    func loadSavedModel() {
        if let savedModelId = UserDefaults.standard.string(forKey: PreferenceKeys.selectedModelId),
           let savedModel = models.first(where: { $0.id == savedModelId }) {
            selectedModel = savedModel
        }
    }

    var hasAPIKey: Bool {
        KeychainService.shared.hasAPIKey
    }
}
