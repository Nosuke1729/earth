// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SecondEarth",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "SecondEarth", targets: ["SecondEarthApp"]),
        .executable(name: "PlanetProbe", targets: ["PlanetProbe"])
    ],
    targets: [
        .target(name: "SimulationEngine"),
        .target(name: "Persistence", dependencies: ["SimulationEngine"]),
        .target(name: "RealWorldInputs", dependencies: ["SimulationEngine"]),
        .target(name: "Rendering", dependencies: ["SimulationEngine"]),
        .executableTarget(name: "SecondEarthApp", dependencies: ["SimulationEngine", "Persistence", "RealWorldInputs", "Rendering"]),
        .executableTarget(name: "PlanetProbe", dependencies: ["SimulationEngine", "Persistence", "Rendering"]),
        .testTarget(name: "SimulationEngineTests", dependencies: ["SimulationEngine"]),
        .testTarget(name: "PersistenceTests", dependencies: ["Persistence", "SimulationEngine"], resources: [.copy("Fixtures")]),
        .testTarget(name: "RenderingTests", dependencies: ["Rendering"])
    ]
)
