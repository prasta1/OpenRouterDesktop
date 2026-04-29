import XCTest
@testable import OpenRouterDesktop

final class MarkdownExportTests: XCTestCase {
    func testTitleAppearsAsH1() {
        let convo = Conversation(name: "My chat", messages: [])
        XCTAssertTrue(convo.markdownExport.hasPrefix("# My chat\n"))
    }

    func testIncludesModelLineWhenSet() {
        var convo = Conversation(name: "X")
        convo.modelID = "openai/gpt-5"
        XCTAssertTrue(convo.markdownExport.contains("_Model: openai/gpt-5_"))
    }

    func testOmitsModelLineWhenNil() {
        let convo = Conversation(name: "X")
        XCTAssertFalse(convo.markdownExport.contains("_Model:"))
    }

    func testIncludesSystemPromptWhenSet() {
        var convo = Conversation(name: "X")
        convo.systemPrompt = "Be concise."
        let md = convo.markdownExport
        XCTAssertTrue(md.contains("## System"))
        XCTAssertTrue(md.contains("Be concise."))
    }

    func testOmitsSystemPromptWhenEmpty() {
        var convo = Conversation(name: "X")
        convo.systemPrompt = ""
        XCTAssertFalse(convo.markdownExport.contains("## System"))
    }

    func testRendersUserAndAssistantHeaders() {
        let convo = Conversation(
            name: "X",
            messages: [
                Message(role: .user, content: "hi"),
                Message(role: .assistant, content: "hello"),
            ]
        )
        let md = convo.markdownExport
        XCTAssertTrue(md.contains("## User\n\nhi"))
        XCTAssertTrue(md.contains("## Assistant\n\nhello"))
    }

    func testEmptyConversationStillRendersTitle() {
        let convo = Conversation(name: "Empty", messages: [])
        XCTAssertEqual(convo.markdownExport, "# Empty\n")
    }
}
