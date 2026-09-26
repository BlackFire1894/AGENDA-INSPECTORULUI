import XCTest
@testable import AgendaKit

/// Căile către datele comune și vectori (docs/nativ/), relativ la acest fișier.
enum Docs {
    static let nativ = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // AgendaKitTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // AgendaKit
        .deletingLastPathComponent() // ios
        .deletingLastPathComponent() // rădăcina repo
        .appendingPathComponent("docs/nativ")

    static func date(_ nume: String) throws -> Data {
        try Data(contentsOf: nativ.appendingPathComponent("date/\(nume)"))
    }

    static func vector(_ nume: String) throws -> Data {
        try Data(contentsOf: nativ.appendingPathComponent("vectori/\(nume)"))
    }
}

final class CatalogTests: XCTestCase {
    func testCatalogulSeCiteste() throws {
        let catalog = try Catalog(data: Docs.date("catalog.json"))
        XCTAssertEqual(catalog.versiuneAplicatieWeb.split(separator: ".").count, 3)
        XCTAssertGreaterThanOrEqual(catalog.schema, 11)
    }
}
