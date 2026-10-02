import AppKit
import SceneKit
import SimulationEngine

/// The same scene accepts value snapshots in a window, wallpaper host or screen saver.
@MainActor
public final class PlanetScene {
    public let scene = SCNScene()
    public let camera = SCNNode()
    public let globe = SCNNode()
    private let surface = SCNMaterial()
    private let clouds = SCNNode()
    private var signature = ""

    public init(planet: Planet) {
        scene.background.contents = NSColor(red: 0.008, green: 0.015, blue: 0.025, alpha: 1)
        camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 42
        camera.camera?.zFar = 200
        camera.position = SCNVector3(0, 0, 3.9)
        scene.rootNode.addChildNode(camera)

        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.intensity = 1_650
        sun.light?.color = NSColor(red: 1, green: 0.92, blue: 0.8, alpha: 1)
        sun.eulerAngles = SCNVector3(-0.3, -1.05, 0)
        scene.rootNode.addChildNode(sun)
        let ambient = SCNNode()
        ambient.light = SCNLight(); ambient.light?.type = .ambient
        ambient.light?.intensity = 65
        ambient.light?.color = NSColor(red: 0.35, green: 0.5, blue: 0.8, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        let sphere = SCNSphere(radius: 1)
        sphere.segmentCount = 128
        sphere.materials = [surface]
        surface.lightingModel = .physicallyBased
        surface.roughness.contents = 0.78
        surface.metalness.contents = 0.0
        globe.geometry = sphere
        globe.name = "planet"
        scene.rootNode.addChildNode(globe)
        globe.simdOrientation = simd_quatf(angle: Float(planet.axialTiltDegrees * .pi / 180), axis: SIMD3(0, 0, 1))

        let cloudSphere = SCNSphere(radius: 1.012)
        cloudSphere.segmentCount = 96
        let cloudMaterial = SCNMaterial()
        cloudMaterial.diffuse.contents = PlanetTextures.clouds(seed: planet.seed)
        cloudMaterial.lightingModel = .lambert
        cloudMaterial.isDoubleSided = false
        cloudMaterial.writesToDepthBuffer = false
        cloudSphere.materials = [cloudMaterial]
        clouds.geometry = cloudSphere
        clouds.name = "clouds"
        globe.addChildNode(clouds)
        clouds.runAction(.repeatForever(.rotateBy(x: 0, y: 2 * .pi, z: 0, duration: 480)))

        let shell = SCNSphere(radius: 1.04)
        shell.segmentCount = 96
        let atmosphere = SCNMaterial()
        atmosphere.lightingModel = .constant
        atmosphere.diffuse.contents = NSColor(red: 0.17, green: 0.5, blue: 0.85, alpha: 0.13)
        atmosphere.transparencyMode = .aOne
        atmosphere.writesToDepthBuffer = false
        atmosphere.blendMode = .add
        atmosphere.shaderModifiers = [.fragment: """
            #pragma transparent
            #pragma body
            float rim = pow(1.0 - abs(dot(normalize(_surface.normal), normalize(_surface.view))), 4.0);
            _output.color = float4(float3(0.10, 0.36, 0.70) * rim * 0.32, rim * 0.32);
            """
        ]
        shell.materials = [atmosphere]
        let atmosphereNode = SCNNode(geometry: shell)
        atmosphereNode.name = "atmosphere"
        globe.addChildNode(atmosphereNode)
        addStars(seed: planet.seed)
        update(planet)
    }

    public func update(_ planet: Planet) {
        let next = "\(Int(planet.hydrology.oceanCoverage * 200)):\(Int(planet.geology.internalHeat * 50)):\(Int(planet.geology.terrainDrift * 100)):\(Int(planet.climate.iceCoverage * 100)):\(planet.biosphere.stage):\(Int(planet.biosphere.biomass * 30)):\(Int(planet.climate.averageTemperature / 3))"
        let ecology = planet.biosphere.ecology.regions.map { r in
            let summary = planet.biosphere.ecology.summary(regionID: r.id)
            return "\(Int(summary.landPigment / r.area * 100)):\(Int(summary.oceanPigment / r.area * 100))"
        }.joined(separator: ":")
        let visualSignature = next + ":" + ecology
        guard visualSignature != signature else { return }
        signature = visualSignature
        let (terrain, emission) = PlanetTextures.surface(planet)
        surface.diffuse.contents = terrain
        surface.emission.contents = emission
        clouds.opacity = CGFloat(min(0.82, 0.24 + planet.hydrology.oceanCoverage * 0.7))
    }

    private func addStars(seed: UInt64) {
        var rng = SeededRandom(seed: seed &+ 5_909)
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = NSColor(white: 0.6, alpha: 1)
        for _ in 0..<380 {
            let z = rng.value(-1...1), angle = rng.value(0...(2 * .pi))
            let radius = sqrt(1 - z * z)
            let sphere = SCNSphere(radius: rng.value(0.007...0.023))
            sphere.segmentCount = 4; sphere.materials = [material]
            let node = SCNNode(geometry: sphere)
            node.position = SCNVector3(radius * cos(angle) * 35, z * 35, radius * sin(angle) * 35)
            scene.rootNode.addChildNode(node)
        }
    }
}
