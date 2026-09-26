import Foundation

/// Catalogul exportat din aplicația web (docs/nativ/date/catalog.json).
/// Se include în aplicație și se citește la pornire; rândurile nu se transcriu în Swift.
/// Etapa 1: doar versiunea și schema. Restul câmpurilor intră în etapa 2.
public struct Catalog: Decodable, Sendable {
    public let versiuneAplicatieWeb: String
    public let schema: Int

    public init(data: Data) throws {
        self = try JSONDecoder().decode(Catalog.self, from: data)
    }

    /// Catalogul din pachetul aplicației (`catalog.json`, copiat din docs/nativ/date/).
    public static func dinPachet(_ bundle: Bundle = .main) throws -> Catalog {
        guard let url = bundle.url(forResource: "catalog", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try Catalog(data: Data(contentsOf: url))
    }
}
