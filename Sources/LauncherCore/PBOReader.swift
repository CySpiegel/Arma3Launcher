import Foundation

public enum PBOReader {
    private static let maximumHeader = 1_024 * 1_024
    private static let maximumEntries = 4_096
    private static let maximumString = 1_024

    public static func read(path: String, from modRoot: URL) throws -> Data? {
        try read(path: path, from: modRoot, observer: nil)
    }

    static func read(path: String, from modRoot: URL, observer: ArtworkIOObserver?) throws -> Data? {
        try Task.checkCancellation()
        let normalized = path.lowercased()
        let components = normalized.split(separator: "/").map(String.init)
        let archiveURLs = try archives(in: modRoot, prioritizedFor: components, observer: observer)
        var cumulativeHeaders = 0
        var exactMatches: [Match] = []
        var fallbackMatches: [Match] = []
        for archive in archiveURLs.prefix(128) {
            try Task.checkCancellation()
            let fileSize = try archive.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            observer?(.read, archive)
            let handle = try FileHandle(forReadingFrom: archive)
            defer { try? handle.close() }
            guard
                let parsed = try readHeader(
                    handle: handle, fileSize: fileSize, cumulativeBytes: &cumulativeHeaders)
            else { continue }
            for entry in parsed.entries {
                let full = ([parsed.prefix] + [entry.name]).filter { !$0.isEmpty }.joined(separator: "/")
                    .replacingOccurrences(of: "\\", with: "/").lowercased()
                let isExact = full == normalized
                let isFallback =
                    parsed.prefix.isEmpty
                    && entry.name.split(separator: "/").last?.lowercased() == components.last
                guard isExact || isFallback else { continue }
                guard entry.method == 0, entry.dataSize <= ArtworkLoader.maximumSourceBytes else {
                    return nil
                }
                let offset = parsed.dataStart.addingReportingOverflow(entry.offset)
                guard !offset.overflow, offset.partialValue <= fileSize,
                    entry.dataSize <= fileSize - offset.partialValue
                else { return nil }
                let match = Match(archive: archive, offset: offset.partialValue, size: entry.dataSize)
                if isExact { exactMatches.append(match) } else { fallbackMatches.append(match) }
            }
        }
        let matches = exactMatches.isEmpty ? fallbackMatches : exactMatches
        guard matches.count <= 1, let match = matches.first else { return nil }
        observer?(.read, match.archive)
        let handle = try FileHandle(forReadingFrom: match.archive)
        defer { try? handle.close() }
        try handle.seek(toOffset: UInt64(match.offset))
        return try handle.read(upToCount: match.size)
    }

    private static func readHeader(
        handle: FileHandle, fileSize: Int, cumulativeBytes: inout Int
    ) throws -> ParsedHeader? {
        var data = Data()
        let limit = min(fileSize, maximumHeader)
        while data.count < limit {
            try Task.checkCancellation()
            let count = min(4_096, limit - data.count)
            guard cumulativeBytes <= 8 * 1_024 * 1_024 - count else { return nil }
            guard let chunk = try handle.read(upToCount: count), !chunk.isEmpty else { return nil }
            data.append(chunk)
            cumulativeBytes += chunk.count
            if let parsed = parseHeader(data, fileSize: fileSize) { return parsed }
        }
        return nil
    }

    private static func archives(
        in root: URL, prioritizedFor components: [String], observer: ArtworkIOObserver?
    ) throws -> [URL] {
        let canonicalRoot = root.resolvingSymlinksInPath().standardizedFileURL
        guard isContained(root, in: canonicalRoot), isDirectory(root) else { return [] }
        observer?(.enumerate, root)
        let rootFiles = try FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
        let addons = rootFiles.first { $0.lastPathComponent.caseInsensitiveCompare("addons") == .orderedSame }
        let addonFiles: [URL]
        if let addons, isContained(addons, in: canonicalRoot), isDirectory(addons) {
            observer?(.enumerate, addons)
            addonFiles =
                (try? FileManager.default.contentsOfDirectory(
                    at: addons, includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles])) ?? []
        } else {
            addonFiles = []
        }
        return (rootFiles + addonFiles).filter {
            guard isContained($0, in: canonicalRoot),
                $0.pathExtension.caseInsensitiveCompare("pbo") == .orderedSame
            else { return false }
            return (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        }
        .sorted {
            let left = components.contains($0.deletingPathExtension().lastPathComponent.lowercased()) ? 0 : 1
            let right = components.contains($1.deletingPathExtension().lastPathComponent.lowercased()) ? 0 : 1
            return left == right
                ? $0.path.localizedStandardCompare($1.path) == .orderedAscending : left < right
        }
    }

    private static func isContained(_ url: URL, in root: URL) -> Bool {
        let candidate = url.resolvingSymlinksInPath().standardizedFileURL.path
        return candidate == root.path || candidate.hasPrefix(root.path + "/")
    }

    private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    private static func parseHeader(_ data: Data, fileSize: Int) -> ParsedHeader? {
        var cursor = PBOCursor(data)
        guard cursor.string(maximum: maximumString) == "", cursor.take(4) == Data("sreV".utf8),
            cursor.skip(16)
        else { return nil }
        var prefix = ""
        while true {
            guard let key = cursor.string(maximum: maximumString) else { return nil }
            if key.isEmpty { break }
            guard let value = cursor.string(maximum: maximumString) else { return nil }
            if key.caseInsensitiveCompare("prefix") == .orderedSame {
                prefix = value.replacingOccurrences(of: "\\", with: "/").trimmingCharacters(
                    in: CharacterSet(charactersIn: "/"))
            }
        }
        var entries: [Entry] = []
        var dataOffset = 0
        for index in 0...maximumEntries {
            guard let name = cursor.string(maximum: maximumString) else { return nil }
            guard let method = cursor.u32(), cursor.skip(12), let dataSize = cursor.u32() else { return nil }
            if name.isEmpty {
                guard method == 0, dataSize == 0 else { return nil }
                return ParsedHeader(prefix: prefix, entries: entries, dataStart: cursor.offset)
            }
            guard index < maximumEntries else { return nil }
            let size = Int(dataSize)
            guard size <= fileSize, dataOffset <= fileSize - size else { return nil }
            entries.append(Entry(name: name, method: method, dataSize: size, offset: dataOffset))
            dataOffset += size
        }
        return nil
    }

    private struct Entry {
        let name: String
        let method: UInt32
        let dataSize: Int
        let offset: Int
    }
    private struct ParsedHeader {
        let prefix: String
        let entries: [Entry]
        let dataStart: Int
    }
    private struct Match {
        let archive: URL
        let offset: Int
        let size: Int
    }
}

private struct PBOCursor {
    let data: Data
    var offset = 0
    init(_ data: Data) { self.data = data }
    mutating func string(maximum: Int) -> String? {
        let start = offset
        while offset < data.count, offset - start <= maximum {
            if data[offset] == 0 {
                defer { offset += 1 }
                return String(data: data[start..<offset], encoding: .utf8)
            }
            offset += 1
        }
        return nil
    }
    mutating func u32() -> UInt32? {
        guard let bytes = take(4) else { return nil }
        return bytes.enumerated().reduce(0) { $0 | UInt32($1.element) << UInt32($1.offset * 8) }
    }
    mutating func take(_ count: Int) -> Data? {
        guard count >= 0, offset <= data.count, count <= data.count - offset else { return nil }
        defer { offset += count }
        return data.subdata(in: offset..<(offset + count))
    }
    mutating func skip(_ count: Int) -> Bool { take(count) != nil }
}
