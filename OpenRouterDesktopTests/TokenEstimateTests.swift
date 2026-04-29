import XCTest
@testable import OpenRouterDesktop

final class TokenEstimateTests: XCTestCase {
    func testEmptyStringIsZero() {
        XCTAssertEqual("".approximateTokenCount, 0)
    }

    func testShortProseUsesWordHeuristic() {
        // 5 words = 6 tokens (5 * 4 / 3 = 6); 24 chars = 6 tokens (chars/4). Tie → 6.
        XCTAssertEqual("Hello world how are you".approximateTokenCount, 6)
    }

    func testLongProsePrefersWordHeuristic() {
        // 12 words → 16 tokens via word path; chars/4 lower for English prose.
        let s = "the quick brown fox jumps over the lazy dog with great speed"
        XCTAssertEqual(s.approximateTokenCount, max(s.count / 4, (12 * 4) / 3))
        XCTAssertGreaterThanOrEqual(s.approximateTokenCount, 16)
    }

    func testCodeUsesCharHeuristic() {
        // Dense punctuation, few words → chars/4 dominates.
        let s = "for(i=0;i<10;i++){print(i);}"
        XCTAssertEqual(s.approximateTokenCount, s.count / 4)
    }

    func testWhitespaceOnlyHasZeroWords() {
        XCTAssertEqual("   ".approximateTokenCount, 0)
    }

    func testMonotonicallyIncreasing() {
        let short = "hello world"
        let long = "hello world hello world hello world hello world"
        XCTAssertGreaterThan(long.approximateTokenCount, short.approximateTokenCount)
    }
}
