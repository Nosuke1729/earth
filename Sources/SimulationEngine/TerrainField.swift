import Foundation

/// Shared spherical field: ecology and rendering observe the same seeded terrain.
public enum TerrainField {
    public static func height(latitude: Double, longitude: Double, seed: UInt64, drift: Double) -> Double {
        fractal(cos(latitude) * cos(longitude) * 2.5 + drift, sin(latitude) * 2.5,
                cos(latitude) * sin(longitude) * 2.5, seed: seed)
    }
    public static func fractal(_ x: Double, _ y: Double, _ z: Double, seed: UInt64) -> Double {
        var value = 0.0, scale = 1.0, weight = 0.53
        for i in 0..<5 {
            value += noise(x * scale, y * scale, z * scale, seed: seed &+ UInt64(i) &* 911) * weight
            scale *= 2.03; weight *= 0.48
        }
        return value
    }
    public static func noise(_ x: Double, _ y: Double, _ z: Double, seed: UInt64) -> Double {
        let ix = Int(floor(x)), iy = Int(floor(y)), iz = Int(floor(z))
        func smooth(_ t: Double) -> Double { t * t * t * (t * (t * 6 - 15) + 10) }
        let tx = smooth(x - floor(x)), ty = smooth(y - floor(y)), tz = smooth(z - floor(z))
        func sample(_ a: Int, _ b: Int, _ c: Int) -> Double {
            var rng = SeededRandom(seed: seed ^ (UInt64(bitPattern: Int64(a)) &* 73856093)
                                   ^ (UInt64(bitPattern: Int64(b)) &* 19349663)
                                   ^ (UInt64(bitPattern: Int64(c)) &* 83492791))
            return rng.unit()
        }
        func mix(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
        let a = mix(mix(sample(ix, iy, iz), sample(ix + 1, iy, iz), tx),
                    mix(sample(ix, iy + 1, iz), sample(ix + 1, iy + 1, iz), tx), ty)
        let b = mix(mix(sample(ix, iy, iz + 1), sample(ix + 1, iy, iz + 1), tx),
                    mix(sample(ix, iy + 1, iz + 1), sample(ix + 1, iy + 1, iz + 1), tx), ty)
        return mix(a, b, tz)
    }
}
