import XCTest
@testable import OpenRouterDesktop

/// Exercises the real macOS Keychain via a unique service name so the user's
/// production API key is never touched. Each test uses a fresh UUID-suffixed
/// service and tears down regardless of pass/fail.
final class KeychainServiceTests: XCTestCase {
    private var service: KeychainService!
    private var serviceName: String!

    override func setUp() {
        super.setUp()
        serviceName = "com.openrouter.desktop.tests.\(UUID().uuidString)"
        service = KeychainService(service: serviceName)
    }

    override func tearDown() {
        service.deleteAPIKey()
        service = nil
        serviceName = nil
        super.tearDown()
    }

    func testInitialStateHasNoKey() {
        XCTAssertNil(service.getAPIKey())
        XCTAssertFalse(service.hasAPIKey)
    }

    func testSaveThenGetReturnsSameValue() {
        XCTAssertTrue(service.saveAPIKey("sk-test-abc-123"))
        XCTAssertEqual(service.getAPIKey(), "sk-test-abc-123")
        XCTAssertTrue(service.hasAPIKey)
    }

    func testSaveOverwritesExistingValue() {
        XCTAssertTrue(service.saveAPIKey("first"))
        XCTAssertTrue(service.saveAPIKey("second"))
        XCTAssertEqual(service.getAPIKey(), "second")
    }

    func testDeleteRemovesValue() {
        XCTAssertTrue(service.saveAPIKey("sk-test"))
        XCTAssertTrue(service.deleteAPIKey())
        XCTAssertNil(service.getAPIKey())
        XCTAssertFalse(service.hasAPIKey)
    }

    func testDeleteOnEmptyIsIdempotent() {
        XCTAssertTrue(service.deleteAPIKey()) // returns true for errSecItemNotFound
        XCTAssertTrue(service.deleteAPIKey())
    }

    func testRoundtripPreservesUnicode() {
        let key = "sk-🔑-日本語-key"
        XCTAssertTrue(service.saveAPIKey(key))
        XCTAssertEqual(service.getAPIKey(), key)
    }
}
