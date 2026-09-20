import Foundation

public struct PAAImage: Sendable, Equatable {
    public let width: Int
    public let height: Int
    public let pixels: Data

    public static func decode(_ data: Data) -> PAAImage? {
        var cursor = ByteCursor(data)
        guard let format = cursor.u16(), format == 0xFF01 || format == 0xFF05 else { return nil }
        while cursor.peek(4) == Data("GGAT".utf8) {
            guard cursor.skip(8), let length = cursor.u32(), length <= 8 * 1_024 * 1_024,
                cursor.skip(Int(length))
            else { return nil }
        }
        guard let paletteLength = cursor.u16(), cursor.skip(Int(paletteLength)) else { return nil }
        var best: PAAImage?
        for _ in 0..<32 {
            guard let rawWidth = cursor.u16(), let rawHeight = cursor.u16() else { return nil }
            if rawWidth == 0 && rawHeight == 0 { break }
            guard let storedLength = cursor.u24(), storedLength <= ArtworkLoader.maximumSourceBytes else {
                return nil
            }
            let isLZO = rawWidth & 0x8000 != 0
            let width = Int(rawWidth & 0x7FFF)
            let height = Int(rawHeight)
            guard width > 0, height > 0, width <= 16_384, height <= 16_384,
                width.multipliedReportingOverflow(by: height).overflow == false
            else { return nil }
            guard let payload = cursor.take(Int(storedLength)) else { return nil }
            guard !isLZO, width <= 128, height <= 128 else { continue }
            let pixels =
                format == 0xFF01
                ? decodeDXT1(payload, width: width, height: height)
                : decodeDXT5(payload, width: width, height: height)
            if let pixels, best == nil || width * height > best!.width * best!.height {
                best = PAAImage(width: width, height: height, pixels: pixels)
            }
        }
        return best
    }

    static func decodeDXT1(_ data: Data, width: Int, height: Int) -> Data? {
        decodeBlocks(data, width: width, height: height, bytesPerBlock: 8) { block in
            let c0 = UInt16(block[0]) | UInt16(block[1]) << 8
            let c1 = UInt16(block[2]) | UInt16(block[3]) << 8
            let colors = colorTable(c0, c1, allowTransparency: true)
            let indices =
                UInt32(block[4]) | UInt32(block[5]) << 8 | UInt32(block[6]) << 16 | UInt32(block[7]) << 24
            return (0..<16).map { colors[Int((indices >> UInt32($0 * 2)) & 3)] }
        }
    }

    static func decodeDXT5(_ data: Data, width: Int, height: Int) -> Data? {
        decodeBlocks(data, width: width, height: height, bytesPerBlock: 16) { block in
            let alphas = alphaTable(block[0], block[1])
            var alphaBits: UInt64 = 0
            for index in 0..<6 { alphaBits |= UInt64(block[2 + index]) << UInt64(index * 8) }
            let c0 = UInt16(block[8]) | UInt16(block[9]) << 8
            let c1 = UInt16(block[10]) | UInt16(block[11]) << 8
            let colors = colorTable(c0, c1, allowTransparency: false)
            let colorBits =
                UInt32(block[12]) | UInt32(block[13]) << 8 | UInt32(block[14]) << 16 | UInt32(block[15]) << 24
            return (0..<16).map { pixel in
                var color = colors[Int((colorBits >> UInt32(pixel * 2)) & 3)]
                color.3 = alphas[Int((alphaBits >> UInt64(pixel * 3)) & 7)]
                return color
            }
        }
    }

    private static func decodeBlocks(
        _ data: Data, width: Int, height: Int, bytesPerBlock: Int,
        decoder: ([UInt8]) -> [(UInt8, UInt8, UInt8, UInt8)]
    ) -> Data? {
        let across = (width + 3) / 4
        let down = (height + 3) / 4
        guard data.count == across * down * bytesPerBlock else { return nil }
        var output = [UInt8](repeating: 0, count: width * height * 4)
        let bytes = [UInt8](data)
        for blockY in 0..<down {
            for blockX in 0..<across {
                let start = (blockY * across + blockX) * bytesPerBlock
                let pixels = decoder(Array(bytes[start..<(start + bytesPerBlock)]))
                for y in 0..<4 {
                    for x in 0..<4 {
                        let px = blockX * 4 + x
                        let py = blockY * 4 + y
                        guard px < width, py < height else { continue }
                        let destination = (py * width + px) * 4
                        let value = pixels[y * 4 + x]
                        output[destination] = value.0
                        output[destination + 1] = value.1
                        output[destination + 2] = value.2
                        output[destination + 3] = value.3
                    }
                }
            }
        }
        return Data(output)
    }

    private static func colorTable(
        _ first: UInt16, _ second: UInt16, allowTransparency: Bool
    ) -> [(UInt8, UInt8, UInt8, UInt8)] {
        let a = rgb565(first)
        let b = rgb565(second)
        if allowTransparency && first <= second {
            return [a, b, mix(a, b, 1, 1), (0, 0, 0, 0)]
        }
        return [a, b, mix(a, b, 2, 1), mix(a, b, 1, 2)]
    }

    private static func rgb565(_ value: UInt16) -> (UInt8, UInt8, UInt8, UInt8) {
        let r = UInt8((Int(value >> 11) * 255 + 15) / 31)
        let g = UInt8((Int((value >> 5) & 63) * 255 + 31) / 63)
        let b = UInt8((Int(value & 31) * 255 + 15) / 31)
        return (r, g, b, 255)
    }

    private static func mix(
        _ a: (UInt8, UInt8, UInt8, UInt8), _ b: (UInt8, UInt8, UInt8, UInt8), _ aw: Int, _ bw: Int
    ) -> (UInt8, UInt8, UInt8, UInt8) {
        let divisor = aw + bw
        return (
            UInt8((Int(a.0) * aw + Int(b.0) * bw) / divisor),
            UInt8((Int(a.1) * aw + Int(b.1) * bw) / divisor),
            UInt8((Int(a.2) * aw + Int(b.2) * bw) / divisor), 255
        )
    }

    private static func alphaTable(_ first: UInt8, _ second: UInt8) -> [UInt8] {
        if first > second {
            return [first, second] + (1...6).map { UInt8((Int(first) * (7 - $0) + Int(second) * $0) / 7) }
        }
        return [first, second] + (1...4).map { UInt8((Int(first) * (5 - $0) + Int(second) * $0) / 5) } + [
            0, 255,
        ]
    }
}

struct ByteCursor {
    let data: Data
    var offset = 0
    init(_ data: Data) { self.data = data }
    mutating func u16() -> UInt16? { takeInteger(2).map { UInt16($0) } }
    mutating func u24() -> Int? { takeInteger(3).map(Int.init) }
    mutating func u32() -> UInt32? { takeInteger(4).map { UInt32($0) } }
    mutating func take(_ count: Int) -> Data? {
        guard count >= 0, offset <= data.count, count <= data.count - offset else { return nil }
        defer { offset += count }
        return data.subdata(in: offset..<(offset + count))
    }
    mutating func skip(_ count: Int) -> Bool { take(count) != nil }
    func peek(_ count: Int) -> Data? {
        guard count >= 0, offset <= data.count, count <= data.count - offset else { return nil }
        return data.subdata(in: offset..<(offset + count))
    }
    private mutating func takeInteger(_ count: Int) -> UInt64? {
        guard let bytes = take(count) else { return nil }
        return bytes.enumerated().reduce(0) { $0 | UInt64($1.element) << UInt64($1.offset * 8) }
    }
}
