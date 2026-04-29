import XCTest
@testable import OpenRouterDesktop

final class LegacyMigrationTests: XCTestCase {
    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    private var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }

    func testNilForEmptyData() {
        XCTAssertNil(ConversationStore.makeMigratedConversation(from: Data(), decoder: decoder))
    }

    func testNilForJunkJSON() {
        let data = Data("not even json".utf8)
        XCTAssertNil(ConversationStore.makeMigratedConversation(from: data, decoder: decoder))
    }

    func testNilForEmptyMessageArray() throws {
        let data = try encoder.encode([Message]())
        XCTAssertNil(ConversationStore.makeMigratedConversation(from: data, decoder: decoder))
    }

    func testTitleDerivedFromFirstUserMessage() throws {
        let messages = [
            Message(role: .user, content: "How do I parse JSON in Swift?"),
            Message(role: .assistant, content: "Use Codable…"),
        ]
        let data = try encoder.encode(messages)
        let convo = try XCTUnwrap(ConversationStore.makeMigratedConversation(from: data, decoder: decoder))
        XCTAssertEqual(convo.name, "How do I parse JSON in Swift?")
        XCTAssertEqual(convo.messages.count, 2)
    }

    func testTitleTruncatesAt40Chars() throws {
        let long = String(repeating: "a", count: 200)
        let data = try encoder.encode([Message(role: .user, content: long)])
        let convo = try XCTUnwrap(ConversationStore.makeMigratedConversation(from: data, decoder: decoder))
        XCTAssertEqual(convo.name.count, 40)
    }

    func testFallbackTitleWhenNoUserMessage() throws {
        let messages = [Message(role: .assistant, content: "preamble")]
        let data = try encoder.encode(messages)
        let convo = try XCTUnwrap(ConversationStore.makeMigratedConversation(from: data, decoder: decoder))
        XCTAssertEqual(convo.name, "Imported chat")
    }

    func testTimestampsCarriedOver() throws {
        let first = Date(timeIntervalSince1970: 1_700_000_000)
        let last = Date(timeIntervalSince1970: 1_700_001_000)
        let messages = [
            Message(role: .user, content: "q", timestamp: first),
            Message(role: .assistant, content: "a", timestamp: last),
        ]
        let data = try encoder.encode(messages)
        let convo = try XCTUnwrap(ConversationStore.makeMigratedConversation(from: data, decoder: decoder))
        XCTAssertEqual(convo.createdAt.timeIntervalSince1970, first.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(convo.updatedAt.timeIntervalSince1970, last.timeIntervalSince1970, accuracy: 0.001)
    }
}
