import Foundation
import Testing

@testable import LauncherCore

@Suite struct ConfigLiteralParserTests {
    @Test func readsLiteralFieldsAndIgnoresCommentsAndExpressions() {
        let source = Data(
            #"""
            // name = "wrong";
            /* logo = "also_wrong.paa"; */
            name = "Line\nName";
            logo = "x\alive\addons\ui\logo\"crop.paa";
            picture = getText(configFile >> "picture");
            """#.utf8)
        let fields = ConfigLiteralParser.fields(in: source)
        #expect(fields["name"] == "Line\nName")
        #expect(fields["logo"] == "x\\alive\\addons\\ui\\logo\"crop.paa")
        #expect(fields["picture"] == nil)
    }

    @Test func rejectsOversizedAndUnterminatedInput() {
        #expect(ConfigLiteralParser.fields(in: Data(repeating: 65, count: 10), maximumBytes: 9).isEmpty)
        #expect(ConfigLiteralParser.fields(in: Data("name = \"missing".utf8)).isEmpty)
    }

    @Test func handlesCRLFSlashAndControlEscapesWithoutEvaluatingValues() {
        let source = Data(
            "name = \"A\\\\B\\r\\n\\tC\";\r\npicture = call compile \"bad\";\r\nlogoOver = \"ok.paa\";"
                .utf8)
        let fields = ConfigLiteralParser.fields(in: source)
        #expect(fields["name"] == "A\\B\r\n\tC")
        #expect(fields["picture"] == nil)
        #expect(fields["logoover"] == "ok.paa")
    }
}

@Suite struct PAAImageTests {
    @Test func dxt1TransparencyAndPartialEdgesAreStraightRGBA() throws {
        let block: [UInt8] = [0, 0, 255, 255, 255, 255, 255, 255]
        let image = try #require(PAAImage.decode(paa(format: 0xFF01, width: 3, height: 2, block: block)))
        #expect(image.width == 3 && image.height == 2)
        #expect(image.pixels.count == 24)
        #expect(Array(image.pixels.prefix(4)) == [0, 0, 0, 0])
    }

    @Test func dxt5ExercisesBothAlphaBranchesAndFourColorInterpolation() throws {
        var greater = [UInt8](repeating: 0, count: 16)
        greater[0] = 200
        greater[1] = 20
        greater[2] = 2  // first pixel alpha index 2
        greater[8] = 0
        greater[9] = 0
        greater[10] = 255
        greater[11] = 255
        greater[12] = 2  // first pixel color index 2 even with reversed endpoints
        let first = try #require(PAAImage.decode(paa(format: 0xFF05, width: 4, height: 4, block: greater)))
        #expect(first.pixels[3] == UInt8((200 * 6 + 20) / 7))
        #expect(Array(first.pixels.prefix(4)) == [85, 85, 85, 174])

        var lesser = greater
        lesser[0] = 10
        lesser[1] = 20
        lesser[2] = 7
        let second = try #require(PAAImage.decode(paa(format: 0xFF05, width: 4, height: 4, block: lesser)))
        #expect(Array(second.pixels.prefix(4)) == [85, 85, 85, 255])
    }

    @Test func rejectsOversizedTagHeadersInvalidDimensionsAndMipOverflow() {
        var oversizedTag = Data([0x01, 0xFF])
        oversizedTag.append(contentsOf: Data("GGATxxxx".utf8))
        appendU32(8 * 1_024 * 1_024 + 1, to: &oversizedTag)
        #expect(PAAImage.decode(oversizedTag) == nil)
        #expect(
            PAAImage.decode(
                paa(
                    format: 0xFF01, width: 4, height: 16_385,
                    block: [UInt8](repeating: 0, count: 32_776))) == nil)

        var tooManyMips = Data([0x01, 0xFF, 0, 0])
        for _ in 0..<33 {
            appendU16(0x8004, to: &tooManyMips)
            appendU16(4, to: &tooManyMips)
            appendU24(0, to: &tooManyMips)
        }
        #expect(PAAImage.decode(tooManyMips) == nil)
    }

    @Test func skipsLZOMipAndRejectsMalformedLengths() throws {
        let valid = [UInt8](repeating: 0, count: 8)
        var data = Data([0x01, 0xFF, 0, 0])
        appendU16(0x8004, to: &data)
        appendU16(4, to: &data)
        appendU24(3, to: &data)
        data.append(contentsOf: [1, 2, 3])
        appendU16(4, to: &data)
        appendU16(4, to: &data)
        appendU24(8, to: &data)
        data.append(contentsOf: valid)
        appendU16(0, to: &data)
        appendU16(0, to: &data)
        #expect(PAAImage.decode(data)?.width == 4)
        #expect(PAAImage.decode(data.dropLast()) == nil)
        #expect(PAAImage.decode(Data([0x05, 0xFF, 0])) == nil)
    }
}

@Suite struct PBOReaderTests {
    @Test func readsPrefixedStoredEntryAndRejectsAmbiguityCompressionAndTraversal() throws {
        try withTemporaryDirectory { root in
            let addons = root.appending(path: "addons")
            try FileManager.default.createDirectory(at: addons, withIntermediateDirectories: true)
            let image = paa(format: 0xFF01, width: 4, height: 4, block: [UInt8](repeating: 0, count: 8))
            try pbo(prefix: "x\\alive\\addons\\ui", entries: [("logo.paa", 0, image)])
                .write(to: addons.appending(path: "ui.pbo"))
            #expect(try PBOReader.read(path: "x/alive/addons/ui/logo.paa", from: root) == image)
            #expect(ArtworkLoader.normalizedReference("../logo.paa") == nil)
            #expect(ArtworkLoader.normalizedReference("C:\\logo.paa") == nil)

            try pbo(prefix: "", entries: [("a/logo.paa", 0, image), ("b/logo.paa", 0, image)])
                .write(to: addons.appending(path: "ambiguous.pbo"))
            #expect(try PBOReader.read(path: "logo.paa", from: root) == nil)
            try pbo(prefix: "bad", entries: [("packed.paa", 1, image)])
                .write(to: addons.appending(path: "bad.pbo"))
            #expect(try PBOReader.read(path: "bad/packed.paa", from: root) == nil)

            var truncated = pbo(prefix: "cut", entries: [("logo.paa", 0, image)])
            truncated.removeLast()
            try truncated.write(to: addons.appending(path: "cut.pbo"))
            #expect(try PBOReader.read(path: "cut/logo.paa", from: root) == nil)
        }
    }

    @Test func loosePathRejectsSymlinkEscape() throws {
        try withTemporaryDirectory { root in
            let outside = root.deletingLastPathComponent().appending(path: UUID().uuidString + ".paa")
            try Data([1]).write(to: outside)
            defer { try? FileManager.default.removeItem(at: outside) }
            try FileManager.default.createSymbolicLink(
                at: root.appending(path: "logo.paa"), withDestinationURL: outside)
            try Data("logo = \"logo.paa\";".utf8).write(to: root.appending(path: "mod.cpp"))
            #expect(try ArtworkLoader.load(from: root) == nil)
        }
    }

    @Test func externalAddonsDirectoryIsRejectedBeforeArchiveLookup() throws {
        try withTemporaryDirectory { root in
            let outside = root.deletingLastPathComponent().appending(path: UUID().uuidString)
            try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: outside) }
            let image = paa(format: 0xFF01, width: 4, height: 4, block: [UInt8](repeating: 0, count: 8))
            try pbo(prefix: "x", entries: [("logo.paa", 0, image)])
                .write(to: outside.appending(path: "x.pbo"))
            try FileManager.default.createSymbolicLink(
                at: root.appending(path: "addons"), withDestinationURL: outside)
            try Data("logo = \"x\\logo.paa\";".utf8).write(to: root.appending(path: "mod.cpp"))
            let recorder = IORecorder()
            #expect(try ArtworkLoader.load(from: root, observer: recorder.record) == nil)
            #expect(!recorder.urls.contains { $0.path.hasPrefix(outside.path) })
        }
    }

    @Test func intermediateLooseSymlinkIsRejectedBeforeExternalEnumerationOrRead() throws {
        try withTemporaryDirectory { root in
            let outside = root.deletingLastPathComponent().appending(path: UUID().uuidString)
            try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: outside) }
            try Data([1]).write(to: outside.appending(path: "logo.paa"))
            try FileManager.default.createSymbolicLink(
                at: root.appending(path: "assets"), withDestinationURL: outside)
            try Data("logo = \"assets/logo.paa\";".utf8).write(to: root.appending(path: "mod.cpp"))
            let recorder = IORecorder()
            #expect(try ArtworkLoader.load(from: root, observer: recorder.record) == nil)
            #expect(!recorder.urls.contains { $0.path.hasPrefix(outside.path) })
        }
    }

    @Test func rejectsCrossArchiveExactAndFallbackAmbiguity() throws {
        try withTemporaryDirectory { root in
            let addons = root.appending(path: "addons")
            try FileManager.default.createDirectory(at: addons, withIntermediateDirectories: true)
            let image = paa(format: 0xFF01, width: 4, height: 4, block: [UInt8](repeating: 0, count: 8))
            try pbo(prefix: "x", entries: [("logo.paa", 0, image)])
                .write(to: addons.appending(path: "one.pbo"))
            try pbo(prefix: "x", entries: [("logo.paa", 0, image)])
                .write(to: addons.appending(path: "two.pbo"))
            #expect(try PBOReader.read(path: "x/logo.paa", from: root) == nil)

            try FileManager.default.removeItem(at: addons.appending(path: "one.pbo"))
            try FileManager.default.removeItem(at: addons.appending(path: "two.pbo"))
            try pbo(prefix: "", entries: [("a/logo.paa", 0, image)])
                .write(to: addons.appending(path: "one.pbo"))
            try pbo(prefix: "", entries: [("b/logo.paa", 0, image)])
                .write(to: addons.appending(path: "two.pbo"))
            #expect(try PBOReader.read(path: "logo.paa", from: root) == nil)
        }
    }

    @Test func manyLargePayloadArchivesChargeActualHeaderBytes() throws {
        try withTemporaryDirectory { root in
            let addons = root.appending(path: "addons")
            try FileManager.default.createDirectory(at: addons, withIntermediateDirectories: true)
            let image = paa(format: 0xFF01, width: 4, height: 4, block: [UInt8](repeating: 0, count: 8))
            try pbo(prefix: "target", entries: [("logo.paa", 0, image)])
                .write(to: addons.appending(path: "target.pbo"))
            let payload = Data(repeating: 7, count: 140_000)
            for index in 0..<65 {
                try pbo(prefix: "other\(index)", entries: [("payload.bin", 0, payload)])
                    .write(to: addons.appending(path: "archive\(index).pbo"))
            }
            #expect(try PBOReader.read(path: "target/logo.paa", from: root) == image)
        }
    }

    @Test func rejectsPBOHeaderStringEntryAndOffsetLimitViolations() throws {
        let image = paa(format: 0xFF01, width: 4, height: 4, block: [UInt8](repeating: 0, count: 8))
        try withTemporaryDirectory { root in
            let prefix = String(repeating: "a", count: 1_024)
            try writeArchive(pbo(prefix: prefix, entries: [("logo.paa", 0, image)]), in: root)
            #expect(try PBOReader.read(path: "\(prefix)/logo.paa", from: root) == image)
        }
        try withTemporaryDirectory { root in
            let prefix = String(repeating: "a", count: 1_025)
            try writeArchive(pbo(prefix: prefix, entries: [("logo.paa", 0, image)]), in: root)
            #expect(try PBOReader.read(path: "logo.paa", from: root) == nil)
        }
        try withTemporaryDirectory { root in
            let entries =
                [("logo.paa", UInt32(0), image)]
                + (0..<4_095).map { ("e\($0)", UInt32(0), Data()) }
            try writeArchive(pbo(prefix: "", entries: entries), in: root)
            #expect(try PBOReader.read(path: "logo.paa", from: root) == image)
        }
        try withTemporaryDirectory { root in
            let entries =
                [("logo.paa", UInt32(0), image)]
                + (0..<4_096).map { ("e\($0)", UInt32(0), Data()) }
            try writeArchive(pbo(prefix: "", entries: entries), in: root)
            #expect(try PBOReader.read(path: "logo.paa", from: root) == nil)
        }
        let extensionPair = (String(repeating: "k", count: 1_024), String(repeating: "v", count: 1_024))
        try withTemporaryDirectory { root in
            try writeArchive(
                pbo(
                    prefix: "", extensionPairs: Array(repeating: extensionPair, count: 500),
                    entries: [("logo.paa", 0, image)]),
                in: root)
            #expect(try PBOReader.read(path: "logo.paa", from: root) == image)
        }
        try withTemporaryDirectory { root in
            try writeArchive(
                pbo(
                    prefix: "", extensionPairs: Array(repeating: extensionPair, count: 512),
                    entries: [("logo.paa", 0, image)]),
                in: root)
            #expect(try PBOReader.read(path: "logo.paa", from: root) == nil)
        }
        try withTemporaryDirectory { root in
            var badOffset = pbo(prefix: "x", entries: [("logo.paa", 0, Data([1, 2, 3, 4]))])
            badOffset.removeLast(4)
            try writeArchive(badOffset, in: root)
            #expect(try PBOReader.read(path: "x/logo.paa", from: root) == nil)
        }
    }

    @Test func rejectsUnsafeReferencesAndDeepLooseTraversal() throws {
        for reference in ["", "/", "a//b", "./a", "a/../b", "https://x/y", "C:/x", "a\u{0001}b"] {
            #expect(ArtworkLoader.normalizedReference(reference) == nil)
        }
        try withTemporaryDirectory { root in
            try Data("logo = \"addons/deep/logo.paa\";".utf8).write(
                to: root.appending(path: "mod.cpp"))
            try FileManager.default.createDirectory(
                at: root.appending(path: "addons/deep"), withIntermediateDirectories: true)
            try Data([1]).write(to: root.appending(path: "addons/deep/logo.paa"))
            #expect(try ArtworkLoader.load(from: root) == nil)
        }
    }
}

@Suite struct OrdinaryImageBoundsTests {
    @Test func rejectsInvalidOverflowingAndOverBudgetMetadata() {
        #expect(OrdinaryImageBounds.accepts(width: 128, height: 128))
        #expect(!OrdinaryImageBounds.accepts(width: 0, height: 1))
        #expect(!OrdinaryImageBounds.accepts(width: 16_385, height: 1))
        #expect(!OrdinaryImageBounds.accepts(width: 10_000, height: 10_000))
        #expect(!OrdinaryImageBounds.accepts(width: .max, height: .max))
    }

    @Test func contrastCanvasOpposesVisibleLogoLuminanceAndIgnoresTransparentPixels() {
        let dark = Data([8, 8, 8, 255, 255, 255, 255, 0])
        let light = Data([245, 245, 245, 255, 0, 0, 0, 0])
        #expect(ArtworkContrast.canvas(width: 2, height: 1, pixels: dark) == .light)
        #expect(ArtworkContrast.canvas(width: 2, height: 1, pixels: light) == .dark)
    }
}

@Suite struct SteamArtworkSourceTests {
    @Test func resolvesDirectAndOneLevelCacheLayoutsInFilenameOrder() throws {
        try withTemporaryDirectory { root in
            let direct = root.appending(path: "123")
            try FileManager.default.createDirectory(at: direct, withIntermediateDirectories: true)
            try Data("logo".utf8).write(to: direct.appending(path: "logo.png"))
            try Data("header".utf8).write(to: direct.appending(path: "header.jpg"))
            #expect(
                try ArtworkLoader.load(
                    from: .steamApplication(appID: 123, cacheRoot: root)) == .encoded(Data("header".utf8)))
        }
        try withTemporaryDirectory { root in
            let nested = root.appending(path: "456/hash")
            try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
            try Data("nested".utf8).write(to: nested.appending(path: "library_header.jpg"))
            #expect(
                try ArtworkLoader.load(
                    from: .steamApplication(appID: 456, cacheRoot: root)) == .encoded(Data("nested".utf8)))
        }
    }

    @Test func missingOversizedAndEscapingCacheSourcesFallBackWithoutExternalIO() throws {
        try withTemporaryDirectory { root in
            let result = try ArtworkLoader.load(
                from: .steamApplication(appID: 1, cacheRoot: root))
            #expect(result == nil)
        }
        try withTemporaryDirectory { root in
            let directory = root.appending(path: "2")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data(repeating: 0, count: ArtworkLoader.maximumSourceBytes + 1).write(
                to: directory.appending(path: "header.jpg"))
            #expect(throws: (any Error).self) {
                try ArtworkLoader.load(from: .steamApplication(appID: 2, cacheRoot: root))
            }
        }
        try withTemporaryDirectory { root in
            let outside = root.deletingLastPathComponent().appending(path: UUID().uuidString)
            try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: outside) }
            try Data("outside".utf8).write(to: outside.appending(path: "header.jpg"))
            try FileManager.default.createSymbolicLink(
                at: root.appending(path: "3"), withDestinationURL: outside)
            let recorder = IORecorder()
            #expect(
                try ArtworkLoader.load(
                    from: .steamApplication(appID: 3, cacheRoot: root), observer: recorder.record) == nil)
            #expect(!recorder.urls.contains { $0.path.hasPrefix(outside.path) })
        }
        try withTemporaryDirectory { root in
            let directory = root.appending(path: "4")
            let outside = root.deletingLastPathComponent().appending(path: UUID().uuidString + ".jpg")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data("outside".utf8).write(to: outside)
            defer { try? FileManager.default.removeItem(at: outside) }
            try FileManager.default.createSymbolicLink(
                at: directory.appending(path: "header.jpg"), withDestinationURL: outside)
            let recorder = IORecorder()
            #expect(
                try ArtworkLoader.load(
                    from: .steamApplication(appID: 4, cacheRoot: root), observer: recorder.record) == nil)
            #expect(!recorder.urls.contains { $0.path == outside.resolvingSymlinksInPath().path })
        }
    }
}

private func paa(format: UInt16, width: UInt16, height: UInt16, block: [UInt8]) -> Data {
    var data = Data()
    appendU16(format, to: &data)
    appendU16(0, to: &data)
    appendU16(width, to: &data)
    appendU16(height, to: &data)
    appendU24(block.count, to: &data)
    data.append(contentsOf: block)
    appendU16(0, to: &data)
    appendU16(0, to: &data)
    return data
}

private func pbo(
    prefix: String, extensionPairs: [(String, String)] = [], entries: [(String, UInt32, Data)]
) -> Data {
    var data = Data([0])
    data.append(contentsOf: Data("sreV".utf8))
    data.append(Data(repeating: 0, count: 16))
    data.append(contentsOf: Data("prefix".utf8))
    data.append(0)
    data.append(contentsOf: Data(prefix.utf8))
    data.append(0)
    for pair in extensionPairs {
        data.append(contentsOf: Data(pair.0.utf8))
        data.append(0)
        data.append(contentsOf: Data(pair.1.utf8))
        data.append(0)
    }
    data.append(0)
    for entry in entries {
        data.append(contentsOf: Data(entry.0.utf8))
        data.append(0)
        appendU32(entry.1, to: &data)
        appendU32(UInt32(entry.2.count), to: &data)
        appendU32(0, to: &data)
        appendU32(0, to: &data)
        appendU32(UInt32(entry.2.count), to: &data)
    }
    data.append(0)
    data.append(Data(repeating: 0, count: 20))
    for entry in entries { data.append(entry.2) }
    return data
}

private func writeArchive(_ data: Data, in root: URL) throws {
    let addons = root.appending(path: "addons")
    try FileManager.default.createDirectory(at: addons, withIntermediateDirectories: true)
    try data.write(to: addons.appending(path: "test.pbo"))
}

private func appendU16(_ value: UInt16, to data: inout Data) {
    data.append(UInt8(value & 255))
    data.append(UInt8(value >> 8))
}
private func appendU24(_ value: Int, to data: inout Data) {
    data.append(UInt8(value & 255))
    data.append(UInt8((value >> 8) & 255))
    data.append(UInt8((value >> 16) & 255))
}
private func appendU32(_ value: UInt32, to data: inout Data) {
    for shift in stride(from: 0, through: 24, by: 8) { data.append(UInt8((value >> UInt32(shift)) & 255)) }
}

private final class IORecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [URL] = []
    var urls: [URL] { lock.withLock { storage } }
    func record(_ operation: ArtworkIOOperation, _ url: URL) {
        _ = operation
        lock.withLock { storage.append(url.resolvingSymlinksInPath().standardizedFileURL) }
    }
}
