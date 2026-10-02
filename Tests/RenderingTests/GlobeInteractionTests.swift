import Foundation
import Testing
import simd
@testable import Rendering

@Suite struct GlobeInteractionTests {
    func distance(_ a: simd_quatd, _ b: simd_quatd) -> Double {
        min(simd_length(a.vector - b.vector), simd_length(a.vector + b.vector))
    }
    @Test func grabbingAndRegrabbingNeverJumps() {
        var c = GlobeRotationController(axialTiltRadians: 0.4)
        c.tick(deltaTime: 0.5)
        let before = c.orientation
        c.beginDrag(at: SIMD2(0.65, 0.1), time: 1)
        c.drag(to: SIMD2(0.65, 0.1), time: 1.01)
        #expect(distance(before, c.orientation) < 0.000001)
        c.drag(to: SIMD2(0.8, 0.3), time: 1.05)
        c.endDrag(time: 1.05); c.tick(deltaTime: 0.1)
        let rotated = c.orientation
        c.beginDrag(at: SIMD2(-0.5, -0.2), time: 2)
        #expect(distance(rotated, c.orientation) < 0.000001)
        #expect(c.angularVelocity == .zero)
    }
    @Test func horizontalAndVerticalFollowThePointer() {
        var h = GlobeRotationController()
        h.beginDrag(at: .zero, time: 1); h.drag(to: SIMD2(0.3, 0), time: 1.1)
        #expect(h.orientation.act(SIMD3(0, 0, 1)).x > 0.1)
        var v = GlobeRotationController()
        v.beginDrag(at: .zero, time: 1); v.drag(to: SIMD2(0, 0.3), time: 1.1)
        #expect(v.orientation.act(SIMD3(0, 0, 1)).y > 0.1)
    }
    @Test func smallDragsStayPreciseAcrossDifferentGrabLocations() {
        for start in [SIMD2<Double>.zero, SIMD2(-0.65, 0.25), SIMD2(0.65, -0.25), SIMD2(0.1, 0.6)] {
            var c = GlobeRotationController()
            c.beginDrag(at: start, time: 1); c.drag(to: start + SIMD2(0.06, 0), time: 1.1)
            #expect(c.orientation.act(SIMD3(0, 0, 1)).x > 0)
            #expect(distance(c.orientation, simd_quatd(angle: 0, axis: SIMD3(0, 1, 0))) < 0.08)
        }
    }
    @Test func fastRimDragsKeepNormalizedUprightNorth() {
        var c = GlobeRotationController()
        c.beginDrag(at: SIMD2(-0.95, -0.2), time: 0)
        for index in 1...500 {
            c.drag(to: SIMD2(sin(Double(index)) * 4, cos(Double(index)) * 4), time: Double(index) * 0.005)
            let north = c.orientation.act(SIMD3(0, 1, 0))
            #expect(c.orientation.vector.x.isFinite)
            #expect(abs(simd_length(c.orientation.vector) - 1) < 0.000001)
            #expect(north.y >= cos(c.tuning.maximumTilt) - 0.000001)
            #expect(abs(north.x) < 0.000001)
        }
    }
    @Test func inertiaDampsThenIdleResumesGradually() {
        var c = GlobeRotationController()
        c.beginDrag(at: .zero, time: 1); c.drag(to: SIMD2(0.45, 0), time: 1.05); c.endDrag(time: 1.05)
        #expect(c.phase == .coasting)
        let speed = simd_length(c.angularVelocity), release = c.orientation
        c.tick(deltaTime: 0.1)
        #expect(simd_length(c.angularVelocity) < speed)
        #expect(distance(release, c.orientation) > 0)
        for _ in 0..<30 { c.tick(deltaTime: 0.1) }
        #expect(c.phase == .idle)
        #expect(c.idleBlend > 0 && c.idleBlend < 1)
    }
    @Test func frameRatesGiveEquivalentDampingAndZoom() {
        var a = GlobeRotationController()
        a.beginDrag(at: .zero, time: 1); a.drag(to: SIMD2(0.5, 0), time: 1.05); a.endDrag(time: 1.05)
        a.zoom(by: -0.5); var b = a
        for _ in 0..<12 { a.tick(deltaTime: 1.0 / 30) }
        for _ in 0..<24 { b.tick(deltaTime: 1.0 / 60) }
        #expect(distance(a.orientation, b.orientation) < 0.000001)
        #expect(abs(a.cameraDistance - b.cameraDistance) < 0.000001)
        #expect(simd_length(a.angularVelocity - b.angularVelocity) < 0.000001)
    }
    @Test func zoomIsBoundedAndInterpolated() {
        var c = GlobeRotationController()
        for _ in 0..<100 { c.zoom(by: -2) }
        #expect(c.targetDistance == c.tuning.minimumDistance)
        #expect(c.cameraDistance == 3.9)
        c.tick(deltaTime: 0.1)
        #expect(c.cameraDistance > c.tuning.minimumDistance && c.cameraDistance < 3.9)
        for _ in 0..<100 { c.zoom(by: 2) }
        #expect(c.targetDistance == c.tuning.maximumDistance)
    }
    @Test func idleStopsDuringDraggingAndHeldReleaseDoesNotSpin() {
        var c = GlobeRotationController()
        c.beginDrag(at: .zero, time: 1); let start = c.orientation
        c.tick(deltaTime: 1)
        #expect(distance(start, c.orientation) == 0)
        c.drag(to: SIMD2(0.4, 0), time: 1.05); c.endDrag(time: 3)
        #expect(c.phase == .resting)
        let released = c.orientation
        c.tick(deltaTime: 0.5)
        #expect(distance(released, c.orientation) == 0)
    }
    @Test func antipodalAndRimMathIsContinuous() {
        let q = GlobeRotationController.arc(from: SIMD3(0, 0, 1), to: SIMD3(0, 0, -1))
        #expect(simd_length(q.act(SIMD3(0, 0, 1)) - SIMD3(0, 0, -1)) < 0.000001)
        let edge = sqrt(0.5)
        #expect(simd_length(GlobeRotationController.project(SIMD2(edge - 0.00001, 0)) - GlobeRotationController.project(SIMD2(edge + 0.00001, 0))) < 0.0001)
    }
}
