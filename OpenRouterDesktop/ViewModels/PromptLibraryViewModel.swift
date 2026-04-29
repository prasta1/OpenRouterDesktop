import Foundation
import SwiftUI

@MainActor
final class PromptLibraryViewModel: ObservableObject {
    @Published private(set) var prompts: [PromptTemplate] = []

    private let store = PromptLibraryStore.shared

    init() {
        if let loaded = store.load() {
            prompts = loaded
        } else {
            prompts = Self.seedPrompts
            store.save(prompts)
        }
    }

    var systemPrompts: [PromptTemplate] {
        prompts.filter { $0.kind == .systemPrompt }
            .sorted { $0.name < $1.name }
    }

    var snippets: [PromptTemplate] {
        prompts.filter { $0.kind == .userSnippet }
            .sorted { $0.name < $1.name }
    }

    func add(_ template: PromptTemplate) {
        prompts.append(template)
        store.save(prompts)
    }

    func update(_ template: PromptTemplate) {
        guard let idx = prompts.firstIndex(where: { $0.id == template.id }) else { return }
        prompts[idx] = template
        store.save(prompts)
    }

    func delete(id: UUID) {
        prompts.removeAll { $0.id == id }
        store.save(prompts)
    }

    func filtered(matching search: String) -> (system: [PromptTemplate], snippets: [PromptTemplate]) {
        guard !search.isEmpty else { return (systemPrompts, snippets) }
        let predicate: (PromptTemplate) -> Bool = {
            $0.name.localizedCaseInsensitiveContains(search) ||
            $0.body.localizedCaseInsensitiveContains(search)
        }
        return (systemPrompts.filter(predicate), snippets.filter(predicate))
    }

    private static let seedPrompts: [PromptTemplate] = [
        // System prompts
        PromptTemplate(
            name: "Concise",
            body: "Be concise. No preamble or flattery. Skip closing pleasantries. Use bullet points where they help.",
            kind: .systemPrompt
        ),
        PromptTemplate(
            name: "Code Reviewer",
            body: "Act as a senior code reviewer. Identify bugs, security issues, and style problems. Reference specific line numbers. Suggest concrete fixes with code snippets.",
            kind: .systemPrompt
        ),
        PromptTemplate(
            name: "B2B Sales Coach",
            body: "You're a senior B2B enterprise sales coach. Direct, specific feedback. Push back when ideas are weak. Use industry terminology (MEDDPICC, BANT, champion, economic buyer).",
            kind: .systemPrompt
        ),
        PromptTemplate(
            name: "CNC Woodworking Expert",
            body: "You're an experienced CNC machinist and woodworker familiar with Carbide Create, LightBurn, and PrusaSlicer. Practical, action-oriented advice for small-batch fabrication.",
            kind: .systemPrompt
        ),

        // User snippets
        PromptTemplate(
            name: "Explain Code",
            body: "Explain what this code does step by step. Call out anything non-obvious.\n\n```\n\n```",
            kind: .userSnippet
        ),
        PromptTemplate(
            name: "Summarize",
            body: "Summarize the following in 3–5 bullet points:\n\n",
            kind: .userSnippet
        ),
        PromptTemplate(
            name: "Polish Writing",
            body: "Improve the writing below. Keep my voice and intent. Make it tighter and clearer. Show only the revised version.\n\n",
            kind: .userSnippet
        ),
        PromptTemplate(
            name: "Draft Customer Email",
            body: "Draft a professional but warm email to a customer. Context:\n\n[situation]\n\nGoal: [what I want them to do]",
            kind: .userSnippet
        ),
        PromptTemplate(
            name: "Translate",
            body: "Translate the following to {language}. Preserve tone.\n\n",
            kind: .userSnippet
        ),
    ]
}
