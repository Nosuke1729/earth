import Foundation

public struct RealWorldInfluence: Codable, Equatable, Sendable {
    public var cpuActivity: Double
    public var isCharging: Bool
    public var uptimeSeconds: Double
    public init(cpuActivity: Double = 0, isCharging: Bool = false, uptimeSeconds: Double = 0) {
        self.cpuActivity = cpuActivity.isFinite ? min(1, max(0, cpuActivity)) : 0
        self.isCharging = isCharging
        self.uptimeSeconds = uptimeSeconds.isFinite ? max(0, uptimeSeconds) : 0
    }
    public static let neutral = RealWorldInfluence()
    public var geologicalModifier: Double { 1 + 0.02 * cpuActivity + 0.005 * min(1, uptimeSeconds / 86_400) }
    public var auroraProbabilityModifier: Double { isCharging ? 1.02 : 1 }
}
