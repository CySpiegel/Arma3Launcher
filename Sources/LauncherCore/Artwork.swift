import Foundation

public enum ArtworkPayload: Sendable, Equatable {
    case encoded(Data)
    case rgba(width: Int, height: Int, pixels: Data)

    public var dimensions: (Int, Int)? {
        if case .rgba(let width, let height, _) = self { return (width, height) }
        return nil
    }
}

public enum ArtworkLoader {
    public static let maximumSourceBytes = 8 * 1_024 * 1_024

    public static func load(from modRoot: URL) throws -> ArtworkPayload? {
        try load(from: modRoot, observer: nil)
    }

    public static func load(from source: ArtworkSource) throws -> ArtworkPayload? {
        switch source {
        case .modDirectory(let root): return try load(from: root)
        case .steamApplication(let appID, let cacheRoot):
            return try steamArtwork(appID: appID, cacheRoot: cacheRoot, observer: nil)
        }
    }

    static func load(
        from source: ArtworkSource, observer: ArtworkIOObserver?
    ) throws -> ArtworkPayload? {
        switch source {
        case .modDirectory(let root): return try load(from: root, observer: observer)
        case .steamApplication(let appID, let cacheRoot):
            return try steamArtwork(appID: appID, cacheRoot: cacheRoot, observer: observer)
        }
    }

    static func load(from modRoot: URL, observer: ArtworkIOObserver?) throws -> ArtworkPayload? {
        try Task.checkCancellation()
        guard let reference = artworkReference(in: modRoot, observer: observer),
            let path = normalizedReference(reference)
        else {
            return nil
        }
        if let loose = try resolveLoose(path, in: modRoot, observer: observer) {
            return try payload(at: loose, observer: observer)
        }
        guard let data = try PBOReader.read(path: path, from: modRoot, observer: observer) else {
            return nil
        }
        return PAAImage.decode(data).map { .rgba(width: $0.width, height: $0.height, pixels: $0.pixels) }
    }

    public static func artworkReference(in modRoot: URL) -> String? {
        artworkReference(in: modRoot, observer: nil)
    }

    private static func artworkReference(in modRoot: URL, observer: ArtworkIOObserver?) -> String? {
        let fields = ["mod.cpp", "meta.cpp"].compactMap { name -> [String: String]? in
            let url = modRoot.appending(path: name)
            guard
                let data = try? boundedData(
                    at: url, maximum: 1_024 * 1_024, observer: observer)
            else { return nil }
            return ConfigLiteralParser.fields(in: data)
        }
        for key in ["logo", "picture", "overviewpicture", "logoover"] {
            for values in fields { if let value = values[key], !value.isEmpty { return value } }
        }
        return nil
    }

    public static func normalizedReference(_ reference: String) -> String? {
        guard !reference.isEmpty,
            !reference.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
            !reference.contains("://"),
            !(reference.count >= 2 && reference[reference.index(after: reference.startIndex)] == ":")
        else { return nil }
        var value = reference.replacingOccurrences(of: "\\", with: "/")
        if value.hasPrefix("/") { value.removeFirst() }
        let parts = value.split(separator: "/", omittingEmptySubsequences: false)
        guard !parts.isEmpty, parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else { return nil }
        return parts.joined(separator: "/")
    }

    private static func resolveLoose(
        _ path: String, in root: URL, observer: ArtworkIOObserver?
    ) throws -> URL? {
        let components = path.split(separator: "/").map(String.init)
        guard components.count <= 2 else { return nil }
        let canonicalRoot = root.resolvingSymlinksInPath().standardizedFileURL
        var current = root
        for (index, component) in components.enumerated() {
            try Task.checkCancellation()
            guard isContained(current, in: canonicalRoot), isDirectory(current) else { return nil }
            observer?(.enumerate, current)
            let children = try FileManager.default.contentsOfDirectory(
                at: current, includingPropertiesForKeys: [.isSymbolicLinkKey], options: [.skipsHiddenFiles])
            guard
                let match = children.filter({
                    $0.lastPathComponent.caseInsensitiveCompare(component) == .orderedSame
                }).only
            else {
                return nil
            }
            current = match
            guard isContained(current, in: canonicalRoot) else { return nil }
            if index < components.count - 1, !isDirectory(current) { return nil }
        }
        return current
    }

    private static func isContained(_ url: URL, in canonicalRoot: URL) -> Bool {
        let candidate = url.resolvingSymlinksInPath().standardizedFileURL.path
        return candidate == canonicalRoot.path || candidate.hasPrefix(canonicalRoot.path + "/")
    }

    private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    private static func payload(at url: URL, observer: ArtworkIOObserver?) throws -> ArtworkPayload? {
        let data = try boundedData(at: url, maximum: maximumSourceBytes, observer: observer)
        switch url.pathExtension.lowercased() {
        case "paa":
            return PAAImage.decode(data).map { .rgba(width: $0.width, height: $0.height, pixels: $0.pixels) }
        case "png", "jpg", "jpeg": return .encoded(data)
        default: return nil
        }
    }

    static func boundedData(
        at url: URL, maximum: Int, observer: ArtworkIOObserver? = nil
    ) throws -> Data {
        observer?(.read, url)
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true, let size = values.fileSize, size <= maximum else {
            throw ArtworkError.invalidOrOversized
        }
        return try Data(contentsOf: url, options: [.mappedIfSafe])
    }

    private static func steamArtwork(
        appID: UInt32, cacheRoot: URL, observer: ArtworkIOObserver?
    ) throws -> ArtworkPayload? {
        try Task.checkCancellation()
        let canonicalRoot = cacheRoot.resolvingSymlinksInPath().standardizedFileURL
        guard isContained(cacheRoot, in: canonicalRoot), isDirectory(cacheRoot) else { return nil }
        let appDirectory = cacheRoot.appending(path: String(appID))
        guard isContained(appDirectory, in: canonicalRoot), isDirectory(appDirectory) else { return nil }
        let names = ["header.jpg", "library_header.jpg", "logo.png"]
        if let payload = try firstEncodedImage(
            in: appDirectory, names: names, canonicalRoot: canonicalRoot, observer: observer)
        {
            return payload
        }
        observer?(.enumerate, appDirectory)
        let children = try FileManager.default.contentsOfDirectory(
            at: appDirectory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        )
        .filter { isContained($0, in: canonicalRoot) && isDirectory($0) }
        .sorted { $0.path < $1.path }
        for child in children.prefix(32) {
            try Task.checkCancellation()
            if let payload = try firstEncodedImage(
                in: child, names: names, canonicalRoot: canonicalRoot, observer: observer)
            {
                return payload
            }
        }
        return nil
    }

    private static func firstEncodedImage(
        in directory: URL, names: [String], canonicalRoot: URL, observer: ArtworkIOObserver?
    ) throws -> ArtworkPayload? {
        guard isContained(directory, in: canonicalRoot), isDirectory(directory) else { return nil }
        observer?(.enumerate, directory)
        let files = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
        for name in names {
            guard
                let file = files.filter({ $0.lastPathComponent == name }).only,
                isContained(file, in: canonicalRoot)
            else { continue }
            return .encoded(try boundedData(at: file, maximum: maximumSourceBytes, observer: observer))
        }
        return nil
    }
}

enum ArtworkIOOperation: Sendable { case enumerate, read }
typealias ArtworkIOObserver = @Sendable (ArtworkIOOperation, URL) -> Void

public enum OrdinaryImageBounds {
    public static let maximumDimension = 16_384
    public static let maximumPixels = 64_000_000

    public static func accepts(width: Int, height: Int) -> Bool {
        guard width > 0, height > 0, width <= maximumDimension, height <= maximumDimension else {
            return false
        }
        let pixels = width.multipliedReportingOverflow(by: height)
        return !pixels.overflow && pixels.partialValue <= maximumPixels
    }
}

public enum ArtworkCanvasTone: Sendable { case light, dark }

public enum ArtworkContrast {
    public static func canvas(width: Int, height: Int, pixels: Data) -> ArtworkCanvasTone {
        guard width > 0, height > 0, pixels.count == width * height * 4 else { return .light }
        var weightedLuminance = 0.0
        var weight = 0.0
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[offset + 3]) / 255
            guard alpha > 0.04 else { continue }
            let luminance =
                0.2126 * Double(pixels[offset]) + 0.7152 * Double(pixels[offset + 1])
                + 0.0722 * Double(pixels[offset + 2])
            weightedLuminance += luminance * alpha
            weight += alpha
        }
        guard weight > 0 else { return .light }
        return weightedLuminance / weight < 118 ? .light : .dark
    }
}

public enum ArtworkError: Error { case invalidOrOversized }

extension Array {
    fileprivate var only: Element? { count == 1 ? self[0] : nil }
}
