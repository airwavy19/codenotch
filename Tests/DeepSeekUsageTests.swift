import XCTest
@testable import Codenotch

final class DeepSeekUsageTests: XCTestCase {
    func testReadsUSDWithoutMixingInOtherCurrencies() throws {
        let json = #"""
        {"is_available":true,"balance_infos":[
          {"currency":"CNY","total_balance":"12.00"},
          {"currency":"USD","total_balance":"4.5"}
        ]}
        """#
        let amount = try XCTUnwrap(DeepSeekUsage.usdBalance(in: Data(json.utf8)))
        XCTAssertEqual(NSDecimalNumber(decimal: amount), NSDecimalNumber(string: "4.5"))
        XCTAssertEqual(DeepSeekUsage.formattedUSD(amount), "$4.50")
    }

    func testMissingUSDBalanceIsNotPretendedToBeZero() throws {
        XCTAssertNil(try DeepSeekUsage.usdBalance(in: Data(#"{"balance_infos":[]}"#.utf8)))
    }

    func testMalformedUSDAmountIsRejected() {
        XCTAssertThrowsError(try DeepSeekUsage.usdBalance(in: Data(#"{"balance_infos":[{"currency":"USD","total_balance":"nope"}]}"#.utf8)))
    }
}

final class DeepSeekCredentialsTests: XCTestCase {
    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("DeepSeekCredentialsTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    func testEnvironmentKeyWinsOverPiAuth() throws {
        let auth = scratch.appendingPathComponent("auth.json")
        try Data(#"{"deepseek":{"key":"pi-key"}}"#.utf8).write(to: auth)
        let credential = DeepSeekCredentials.load(environment: ["DEEPSEEK_API_KEY": " env-key "], piAuthURL: auth)
        XCTAssertEqual(credential, .init(token: "env-key", source: "DEEPSEEK_API_KEY"))
    }

    func testReadsPiAuthKey() throws {
        let auth = scratch.appendingPathComponent("auth.json")
        try Data(#"{"deepseek":{"apiKey":" pi-key "}}"#.utf8).write(to: auth)
        XCTAssertEqual(DeepSeekCredentials.load(environment: [:], piAuthURL: auth),
                       .init(token: "pi-key", source: "Pi"))
    }
}
