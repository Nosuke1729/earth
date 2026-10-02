import AppKit
import SceneKit
import simd
import SimulationEngine

@MainActor
final class InteractivePlanetView: SCNView {
    var planetScene: PlanetScene?
    var onObserve: ((Int?) -> Void)?
    private var clickedRegion: Int?
    var controller = GlobeRotationController()
    private var animationTimer: Timer?
    private var lastFrameTime = 0.0
    private var requestedActive = false
    private var dragStart: NSPoint?
    private var dragTravel = 0.0
    private var dragProjection: (center: SIMD2<Double>, radius: Double)?

    func configure(planetScene: PlanetScene, axialTilt: Double, active: Bool) {
        self.planetScene = planetScene
        controller = GlobeRotationController(axialTiltRadians: axialTilt * .pi / 180)
        scene = planetScene.scene; pointOfView = planetScene.camera
        allowsCameraControl = false
        antialiasingMode = .multisampling4X; preferredFramesPerSecond = 30
        planetScene.camera.camera?.projectionDirection = .vertical
        applyObservationState(); setActive(active)
    }
    func setActive(_ active: Bool) { requestedActive = active; refreshVisibility() }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self, name: NSWindow.didChangeOcclusionStateNotification, object: nil)
        if let window {
            NotificationCenter.default.addObserver(self, selector: #selector(refreshVisibility),
                name: NSWindow.didChangeOcclusionStateNotification, object: window)
        }
        refreshVisibility()
    }
    @objc private func refreshVisibility() {
        let animate = requestedActive && (window?.occlusionState.contains(.visible) ?? false)
        isPlaying = animate; scene?.isPaused = !animate
        guard animate else {
            animationTimer?.invalidate(); animationTimer = nil
            if controller.phase == .dragging { controller.cancelDrag(); dragStart = nil; dragProjection = nil }
            return
        }
        guard animationTimer == nil else { return }
        lastFrameTime = ProcessInfo.processInfo.systemUptime
        let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            // Native input and this timer share the main run loop.
            MainActor.assumeIsolated { self?.animateFrame() }
        }
        animationTimer = timer; RunLoop.main.add(timer, forMode: .common)
    }
    func stop() { requestedActive = false; refreshVisibility(); NotificationCenter.default.removeObserver(self) }
    private func animateFrame() {
        let now = ProcessInfo.processInfo.systemUptime
        controller.tick(deltaTime: min(0.1, max(0, now - lastFrameTime)))
        lastFrameTime = now; applyObservationState()
    }
    private func applyObservationState() {
        SCNTransaction.begin(); SCNTransaction.disableActions = true
        planetScene?.globe.simdOrientation = simd_quatf(vector: SIMD4<Float>(controller.orientation.vector))
        planetScene?.camera.position = SCNVector3(0, 0, controller.cameraDistance)
        SCNTransaction.commit()
    }
    private func localPoint(_ event: NSEvent) -> NSPoint { convert(event.locationInWindow, from: nil) }
    private func projectionGeometry() -> (center: SIMD2<Double>, radius: Double) {
        let fov = Double(planetScene?.camera.camera?.fieldOfView ?? 42) * .pi / 180
        let focal = Double(bounds.height) / (2 * tan(fov / 2))
        let radius = max(1, focal / sqrt(controller.cameraDistance * controller.cameraDistance - 1))
        return (SIMD2(Double(bounds.midX), Double(bounds.midY)), radius)
    }
    private func trackballPoint(_ point: NSPoint) -> SIMD2<Double> {
        // Freeze geometry for a gesture; concurrent zoom or a panel resize
        // cannot turn a stationary cursor into an unexpected rotation.
        let geometry = dragProjection ?? projectionGeometry()
        let y = isFlipped ? bounds.height - point.y : point.y
        return (SIMD2(Double(point.x), Double(y)) - geometry.center) / geometry.radius
    }
    override func mouseDown(with event: NSEvent) {
        let point = localPoint(event)
        let hits = hitTest(point, options: [.searchMode: SCNHitTestSearchMode.all.rawValue])
        guard let hit = hits.first(where: { $0.node.name == "planet" }) else { return }
        let uv = hit.textureCoordinates(withMappingChannel: 0)
        clickedRegion = EcologicalGrid.regionIndex(u: Double(uv.x), imageY: 1 - Double(uv.y))
        dragStart = point; dragTravel = 0
        dragProjection = projectionGeometry()
        controller.beginDrag(at: trackballPoint(point), time: event.timestamp)
        NSCursor.closedHand.set()
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDragged(with event: NSEvent) {
        guard let dragStart else { return }
        let point = localPoint(event)
        dragTravel = max(dragTravel, hypot(point.x - dragStart.x, point.y - dragStart.y))
        controller.drag(to: trackballPoint(point), time: event.timestamp); applyObservationState()
    }
    override func mouseUp(with event: NSEvent) {
        guard dragStart != nil else { return }
        controller.endDrag(time: event.timestamp); dragStart = nil; dragProjection = nil
        NSCursor.openHand.set()
        if dragTravel < 3 { onObserve?(clickedRegion) }
        clickedRegion = nil
    }
    override func scrollWheel(with event: NSEvent) {
        let sensitivity = event.hasPreciseScrollingDeltas ? controller.tuning.preciseZoomSensitivity : controller.tuning.wheelZoomSensitivity
        controller.zoom(by: -Double(event.scrollingDeltaY) * sensitivity)
    }
    override func magnify(with event: NSEvent) { controller.zoom(by: -Double(event.magnification)) }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
}
