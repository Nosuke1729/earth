import Foundation

/// SplitMix64. The exact state is saved; rendering uses its own independent stream.
public struct SeededRandom: Codable, Equatable, Sendable {
    public private(set) var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    public mutating func unit() -> Double { Double(next() >> 11) / 9_007_199_254_740_992 }
    public mutating func value(_ range: ClosedRange<Double>) -> Double {
        range.lowerBound + unit() * (range.upperBound - range.lowerBound)
    }
    public mutating func occurs(ratePerMillionYears rate: Double, millionYears: Double) -> Bool {
        unit() < -expm1(-max(0, rate) * millionYears)
    }
}

func bounded(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
    min(upper, max(lower, value))
}
