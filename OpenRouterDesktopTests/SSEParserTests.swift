import XCTest
@testable import OpenRouterDesktop

final class SSEParserTests: XCTestCase {
    func testIgnoresNonDataLines() {
        XCTAssertEqual(OpenRouterService.parseSSELine(""), .ignore)
        XCTAssertEqual(OpenRouterService.parseSSELine(": comment"), .ignore)
        XCTAssertEqual(OpenRouterService.parseSSELine("event: ping"), .ignore)
    }

    func testRecognizesDoneSentinel() {
        XCTAssertEqual(OpenRouterService.parseSSELine("data: [DONE]"), .done)
    }

    func testExtractsContentDelta() {
        let line = #"data: {"choices":[{"delta":{"content":"Hello"}}]}"#
        XCTAssertEqual(OpenRouterService.parseSSELine(line), .delta("Hello"))
    }

    func testIgnoresRoleOnlyDelta() {
        // First chunk often has role but no content — that's not malformed, just skip it.
        let line = #"data: {"choices":[{"delta":{"role":"assistant"}}]}"#
        XCTAssertEqual(OpenRouterService.parseSSELine(line), .ignore)
    }

    func testIgnoresEmptyContentDelta() {
        let line = #"data: {"choices":[{"delta":{"content":""}}]}"#
        XCTAssertEqual(OpenRouterService.parseSSELine(line), .ignore)
    }

    func testMalformedJSONReturnsMalformed() {
        let line = "data: {not json"
        if case .malformed(let payload) = OpenRouterService.parseSSELine(line) {
            XCTAssertEqual(payload, "{not json")
        } else {
            XCTFail("expected .malformed for unparseable JSON")
        }
    }

    func testJSONShapeMismatchReturnsMalformed() {
        // Valid JSON, wrong shape — still want this surfaced.
        let line = #"data: {"unexpected":"shape"}"#
        if case .malformed = OpenRouterService.parseSSELine(line) {
            // pass
        } else {
            XCTFail("expected .malformed for schema mismatch")
        }
    }

    func testHandlesMultiLineContentInDelta() {
        let line = #"data: {"choices":[{"delta":{"content":"line1\nline2"}}]}"#
        XCTAssertEqual(OpenRouterService.parseSSELine(line), .delta("line1\nline2"))
    }
}
