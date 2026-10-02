import Foundation
import simd

public struct GlobeInteractionTuning: Sendable {
    public var rotationSensitivity = 0.9
    public var inertiaStrength = 0.22
    public var rotationDamping = 6.5
    public var idleRotationSpeed = 0.024
    public var idleResumeDelay = 0.8
    public var idleBlendTime = 0.7
    public var maximumTilt = 70.0 * Double.pi / 180
    public var maximumAngularVelocity = 4.0
    public var minimumDistance = 3.0
    public var maximumDistance = 6.0
    public var zoomResponse = 12.0
    public var preciseZoomSensitivity = 0.006
    public var wheelZoomSensitivity = 0.035
    public init() {}
}

public enum GlobeMotionPhase: Sendable { case idle, dragging, coasting, resting }

/// Pure observation math: no simulation, RNG, persistence or frame APIs.
public struct GlobeRotationController: Sendable {
    public let tuning: GlobeInteractionTuning
    public private(set) var orientation: simd_quatd
    public private(set) var angularVelocity = SIMD3<Double>.zero
    public private(set) var phase = GlobeMotionPhase.idle
    public private(set) var cameraDistance = 3.9
    public private(set) var targetDistance = 3.9
    public private(set) var idleBlend = 1.0
    private let northLean: simd_quatd
    private var previousPoint: SIMD2<Double>?
    private var previousTime = 0.0
    private var lastMotionTime = 0.0
    private var restTime = 0.0

    public init(tuning: GlobeInteractionTuning = .init(), axialTiltRadians: Double = 0) {
        self.tuning = tuning
        northLean = simd_quatd(angle: axialTiltRadians, axis: SIMD3(0, 0, 1))
        orientation = northLean
    }

    public static func project(_ point: SIMD2<Double>) -> SIMD3<Double> {
        let squared = simd_length_squared(point)
        // Continuous sphere/hyperbolic-sheet projection across the globe's rim.
        let z = squared <= 0.5 ? sqrt(max(0, 1 - squared)) : 0.5 / sqrt(squared)
        return simd_normalize(SIMD3(point.x, point.y, z))
    }

    public static func arc(from: SIMD3<Double>, to: SIMD3<Double>) -> simd_quatd {
        let dot = min(1, max(-1, simd_dot(from, to)))
        if dot < -0.999999 {
            let basis = abs(from.x) < 0.8 ? SIMD3<Double>(1, 0, 0) : SIMD3<Double>(0, 1, 0)
            return simd_quatd(angle: .pi, axis: simd_normalize(simd_cross(from, basis)))
        }
        let axis = simd_cross(from, to)
        return simd_normalize(simd_quatd(ix: axis.x, iy: axis.y, iz: axis.z, r: 1 + dot))
    }

    public mutating func beginDrag(at point: SIMD2<Double>, time: Double) {
        guard point.x.isFinite, point.y.isFinite, time.isFinite else { return }
        previousPoint = point; previousTime = time; lastMotionTime = time
        angularVelocity = .zero; idleBlend = 0; restTime = 0; phase = .dragging
    }

    public mutating func drag(to point: SIMD2<Double>, time: Double) {
        guard phase == .dragging, let previousPoint,
              point.x.isFinite, point.y.isFinite, time.isFinite else { return }
        let elapsed = max(0.001, time - previousTime)
        let before = orientation
        // Subdivide pointer travel so fast moves cannot leap across the north constraint.
        let count = min(128, max(1, Int(ceil(min(16, simd_length(point - previousPoint)) / 0.08))))
        var start = Self.project(previousPoint)
        for index in 1...count {
            let position = previousPoint + (point - previousPoint) * Double(index) / Double(count)
            let end = Self.project(position)
            let delta = Self.arc(from: start, to: end)
            let scaled = simd_slerp(simd_quatd(angle: 0, axis: SIMD3(0, 1, 0)), delta, tuning.rotationSensitivity)
            orientation = constrained(scaled * orientation)
            start = end
        }
        let delta = simd_normalize(orientation * before.inverse)
        let angle = 2 * atan2(simd_length(delta.imag), abs(delta.real))
        if angle > 0.000001 {
            var velocity = simd_normalize(delta.imag) * (delta.real >= 0 ? 1.0 : -1.0) * angle / elapsed
            let speed = simd_length(velocity)
            if speed > tuning.maximumAngularVelocity { velocity *= tuning.maximumAngularVelocity / speed }
            angularVelocity += (velocity - angularVelocity) * -expm1(-elapsed / 0.04)
            lastMotionTime = time
        }
        self.previousPoint = point; previousTime = max(previousTime, time)
    }

    public mutating func endDrag(time: Double) {
        guard phase == .dragging else { return }
        previousPoint = nil
        angularVelocity *= tuning.inertiaStrength * exp(-max(0, time - lastMotionTime) * tuning.rotationDamping)
        phase = simd_length(angularVelocity) > 0.012 ? .coasting : .resting
        restTime = 0
    }
    public mutating func cancelDrag() {
        previousPoint = nil; angularVelocity = .zero; phase = .resting; restTime = 0; idleBlend = 0
    }
    public mutating func zoom(by logarithmicDelta: Double) {
        guard logarithmicDelta.isFinite else { return }
        targetDistance = min(tuning.maximumDistance, max(tuning.minimumDistance,
            targetDistance * exp(min(2, max(-2, logarithmicDelta)))))
    }

    public mutating func tick(deltaTime: Double) {
        guard deltaTime.isFinite, deltaTime > 0 else { return }
        cameraDistance += (targetDistance - cameraDistance) * -expm1(-tuning.zoomResponse * deltaTime)
        var remaining = min(deltaTime, 1)
        while remaining > 0.0000001 {
            let dt = min(remaining, 1.0 / 120)
            switch phase {
            case .dragging: break
            case .coasting:
                let speed = simd_length(angularVelocity)
                if speed > 0 {
                    // Integrate exponential damping analytically, independent of frame rate.
                    let angle = speed * -expm1(-tuning.rotationDamping * dt) / tuning.rotationDamping
                    orientation = constrained(simd_quatd(angle: angle, axis: angularVelocity / speed) * orientation)
                }
                angularVelocity *= exp(-tuning.rotationDamping * dt)
                if simd_length(angularVelocity) < 0.012 { angularVelocity = .zero; phase = .resting; restTime = 0 }
            case .resting:
                restTime += dt
                if restTime >= tuning.idleResumeDelay { phase = .idle }
            case .idle:
                let oldBlend = idleBlend
                idleBlend = 1 - (1 - idleBlend) * exp(-dt / tuning.idleBlendTime)
                let blendedTime = dt - (1 - oldBlend) * tuning.idleBlendTime * -expm1(-dt / tuning.idleBlendTime)
                orientation = simd_normalize(orientation * simd_quatd(angle: tuning.idleRotationSpeed * blendedTime, axis: SIMD3(0, 1, 0)))
            }
            remaining -= dt
        }
    }

    /// Project geometric north and heading onto an upright quaternion basis,
    /// preserving the original axial lean. No accumulated Euler angles.
    private func constrained(_ candidate: simd_quatd) -> simd_quatd {
        let unleaned = northLean.inverse * simd_normalize(candidate)
        let north = unleaned.act(SIMD3(0, 1, 0))
        let projectedNorth = SIMD3<Double>(0, north.y, north.z)
        var upright = simd_length_squared(projectedNorth) > 0.0000001 ? simd_normalize(projectedNorth) : SIMD3(0, 1, 0)
        let coneBoundary = cos(tuning.maximumTilt)
        if upright.y < coneBoundary {
            upright = SIMD3(0, coneBoundary, copysign(sin(tuning.maximumTilt), upright.z))
        }
        let pitch = Self.arc(from: SIMD3(0, 1, 0), to: upright)
        let forward = (pitch.inverse * unleaned).act(SIMD3(0, 0, 1))
        let horizontal = SIMD3<Double>(forward.x, 0, forward.z)
        let heading = simd_length_squared(horizontal) > 0.0000001 ? simd_normalize(horizontal) : SIMD3(0, 0, 1)
        return simd_normalize(northLean * pitch * Self.arc(from: SIMD3(0, 0, 1), to: heading))
    }
}
