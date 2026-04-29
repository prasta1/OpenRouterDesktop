import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var modelsViewModel: ModelsViewModel
    @AppStorage(PreferenceKeys.temperature) private var temperature: Double = DefaultParameters.temperature
    @AppStorage(PreferenceKeys.maxTokens) private var maxTokens: Int = DefaultParameters.maxTokens
    @State private var apiKeyInput: String = ""
    @State private var showAPIKey: Bool = false
    @State private var keyIsMasked: Bool = false
    @State private var saveStatus: String?

    var body: some View {
        Form {
            Section {
                apiKeySection
            } header: {
                Text("API Configuration")
            }

            Section {
                temperatureSection
                maxTokensSection
            } header: {
                Text("Model Parameters")
            }

            Section {
                aboutSection
            }
        }
        .formStyle(.grouped)
        .background(.ultraThinMaterial)
        .frame(width: 450, height: 350)
        .onAppear {
            loadExistingAPIKey()
        }
    }

    private var apiKeySection: some View {
        HStack {
            if showAPIKey {
                TextField("API Key", text: $apiKeyInput)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: apiKeyInput) { keyIsMasked = false }
            } else {
                SecureField("API Key", text: $apiKeyInput)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: apiKeyInput) { keyIsMasked = false }
            }

            Button(action: { showAPIKey.toggle() }) {
                Image(systemName: showAPIKey ? "eye.slash" : "eye")
            }
            .buttonStyle(.borderless)

            Button("Save") {
                saveAPIKey()
            }
            .buttonStyle(.borderedProminent)
            .disabled(apiKeyInput.isEmpty || keyIsMasked)
        }
    }

    private var temperatureSection: some View {
        HStack {
            Text("Temperature")
            Spacer()
            Slider(value: $temperature, in: 0...2, step: 0.1)
                .frame(width: 200)
            Text(String(format: "%.1f", temperature))
                .frame(width: 30)
        }
    }

    private var maxTokensSection: some View {
        HStack {
            Text("Max Tokens")
            Spacer()
            TextField("Max Tokens", value: $maxTokens, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OpenRouterDesktop")
                .font(.headline)
            Text("Version 1.0.0")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("A native macOS client for OpenRouter API")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func loadExistingAPIKey() {
        if let existingKey = KeychainService.shared.getAPIKey() {
            apiKeyInput = String(repeating: "•", count: min(existingKey.count, 20))
            keyIsMasked = true
        }
    }

    private func saveAPIKey() {
        guard !keyIsMasked else { return }

        if KeychainService.shared.saveAPIKey(apiKeyInput) {
            apiKeyInput = String(repeating: "•", count: min(apiKeyInput.count, 20))
            keyIsMasked = true
            saveStatus = "Saved!"
            Task {
                await modelsViewModel.fetchModels()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                saveStatus = nil
            }
        } else {
            saveStatus = "Failed to save"
        }
    }
}
