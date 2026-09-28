// swift-tools-version: 5.9
// Logica pură a aplicației (fără UI): modelul, catalogul, termenele, statisticile.
// Portează js/model.js, js/dates.js, js/activitati.js cu aceleași nume de funcții.
// Testele rulează pe Mac (`swift test`) și citesc vectorii din docs/nativ/vectori/.
import PackageDescription

let package = Package(
    name: "AgendaKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AgendaKit", targets: ["AgendaKit"]),
    ],
    targets: [
        .target(name: "AgendaKit"),
        .testTarget(name: "AgendaKitTests", dependencies: ["AgendaKit"]),
    ]
)
