import AppKit
import SimulationEngine

enum PlanetTextures {
    static func surface(_ p: Planet, width: Int = 1024, height: Int = 512) -> (NSImage, NSImage) {
        let land = bitmap(width, height)
        let glow = bitmap(width, height)
        var heights = [Double](repeating: 0, count: width * height)
        for y in 0..<height {
            let latitude = .pi * (Double(y) / Double(height - 1) - 0.5)
            for x in 0..<width {
                let longitude = 2 * .pi * Double(x) / Double(width)
                heights[y * width + x] = TerrainField.height(latitude: latitude, longitude: longitude, seed: p.seed, drift: p.geology.terrainDrift)
            }
        }
        let sorted = heights.sorted()
        let sea = p.biosphere.ecology.regions.isEmpty ? sorted[min(sorted.count - 1, Int(p.hydrology.oceanCoverage * Double(sorted.count - 1)))] : p.biosphere.ecology.seaLevel
        let summaries = p.biosphere.ecology.regions.map { p.biosphere.ecology.summary(regionID: $0.id) }
        let landPigments = p.biosphere.ecology.regions.map { min(0.3, summaries[$0.id].landPigment / $0.area * 0.5) }
        let oceanPigments = p.biosphere.ecology.regions.map { min(0.3, summaries[$0.id].oceanPigment / $0.area * 0.5) }
        let iceEdge = 1 - p.climate.iceCoverage
        for y in 0..<height {
            let latitude = .pi * (Double(y) / Double(height - 1) - 0.5)
            for x in 0..<width {
                let h = heights[y * width + x]
                let ocean = p.hydrology.oceanCoverage > 0.001 && h <= sea
                let detail = TerrainField.noise(Double(x) / 15, Double(y) / 15, 3, seed: p.seed)
                var c: (Double, Double, Double)
                if ocean {
                    let shallow = max(0, 1 - (sea - h) * 18)
                    c = (0.012 + shallow * 0.02, 0.055 + shallow * 0.12, 0.12 + shallow * 0.13)
                } else {
                    let elevation = max(0, h - sea)
                    let tint = 0.75 + detail * 0.25
                    c = ((0.22 + elevation * 0.4) * tint, (0.19 + elevation * 0.35) * tint, (0.155 + elevation * 0.3) * tint)

                }
                let pigment = regionalPigment(ocean ? oceanPigments : landPigments, u: Double(x) / Double(width), imageY: Double(y) / Double(height - 1))
                if ocean { c.1 += pigment * 0.10; c.2 *= 1 - pigment * 0.12 }
                else { c.0 *= 1 - pigment * 0.6; c.1 += pigment * 0.15; c.2 *= 1 - pigment * 0.3 }
                if p.climate.iceCoverage > 0.02 && abs(sin(latitude)) > iceEdge + (detail - 0.5) * 0.05 {
                    c = (0.72 + detail * 0.15, 0.8 + detail * 0.13, 0.84 + detail * 0.12)
                }
                set(land, x, y, c, alpha: 1)
                let volcanicMask = min(1, max(0, (h - 0.5) * 12)) * min(1, max(0, (detail - 0.52) * 12))
                let intensity = max(0, p.geology.internalHeat - 0.45) * volcanicMask
                set(glow, x, y, (intensity, intensity * 0.13, 0.006 * intensity), alpha: 1)
            }
        }
        return (image(land), image(glow))
    }

    static func clouds(seed: UInt64) -> NSImage {
        let width = 768, height = 384
        let result = bitmap(width, height)
        for y in 0..<height {
            let lat = .pi * (Double(y) / Double(height - 1) - 0.5)
            for x in 0..<width {
                let lon = 2 * .pi * Double(x) / Double(width)
                let n = TerrainField.fractal(cos(lat) * cos(lon) * 5, sin(lat) * 7,
                                cos(lat) * sin(lon) * 5, seed: seed &+ 43)
                let alpha = min(0.88, max(0, (n - 0.53) * 6))
                set(result, x, y, (0.84, 0.89, 0.95), alpha: alpha)
            }
        }
        return image(result)
    }

    private static func bitmap(_ w: Int, _ h: Int) -> NSBitmapImageRep {
        NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                         colorSpaceName: .deviceRGB, bitmapFormat: .alphaNonpremultiplied,
                         bytesPerRow: w * 4, bitsPerPixel: 32)!
    }
    private static func set(_ b: NSBitmapImageRep, _ x: Int, _ y: Int, _ c: (Double, Double, Double), alpha: Double) {
        let offset = y * b.bytesPerRow + x * 4
        let bytes = b.bitmapData!
        bytes[offset] = UInt8(min(255, max(0, c.0 * 255)))
        bytes[offset + 1] = UInt8(min(255, max(0, c.1 * 255)))
        bytes[offset + 2] = UInt8(min(255, max(0, c.2 * 255)))
        bytes[offset + 3] = UInt8(min(255, max(0, alpha * 255)))
    }
    private static func image(_ bitmap: NSBitmapImageRep) -> NSImage {
        let image = NSImage(size: NSSize(width: bitmap.pixelsWide, height: bitmap.pixelsHigh))
        image.addRepresentation(bitmap)
        return image
    }
    private static func regionalPigment(_ values: [Double], u: Double, imageY: Double) -> Double {
        guard values.count == EcologicalGrid.count else { return 0 }
        let x = u * 8 - 0.5, y = min(5, max(0, imageY * 6 - 0.5))
        let ix = Int(floor(x)), iy = Int(floor(y)), tx = x - floor(x), ty = y - floor(y)
        func at(_ column: Int, _ row: Int) -> Double { values[min(5, row) * 8 + (column + 8) % 8] }
        let lower = at(ix, iy) * (1 - tx) + at(ix + 1, iy) * tx
        let upper = at(ix, iy + 1) * (1 - tx) + at(ix + 1, iy + 1) * tx
        return lower * (1 - ty) + upper * ty
    }
}
