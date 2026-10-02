import SwiftUI
import SceneKit
import SimulationEngine

public struct PlanetView: NSViewRepresentable {
    public var planet: Planet
    public var active: Bool
    public var onObserve: (Int?) -> Void
    public init(planet: Planet, active: Bool, onObserve: @escaping (Int?) -> Void) {
        self.planet = planet; self.active = active; self.onObserve = onObserve
    }
    public func makeNSView(context: Context) -> SCNView {
        let view = InteractivePlanetView()
        view.configure(planetScene: PlanetScene(planet: planet), axialTilt: planet.axialTiltDegrees, active: active)
        view.onObserve = onObserve
        return view
    }
    public func updateNSView(_ view: SCNView, context: Context) {
        guard let view = view as? InteractivePlanetView else { return }
        view.planetScene?.update(planet)
        view.onObserve = onObserve
        view.setActive(active)
    }
    public static func dismantleNSView(_ view: SCNView, coordinator: ()) {
        (view as? InteractivePlanetView)?.stop()
    }
}
