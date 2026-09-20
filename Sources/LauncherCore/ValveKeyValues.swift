import Foundation

public enum ValveValue: Equatable, Sendable {
    case string(String)
    case object([(String, ValveValue)])

    public static func == (lhs: ValveValue, rhs: ValveValue) -> Bool {
        switch (lhs, rhs) {
        case (.string(let a), .string(let b)): return a == b
        case (.object(let a), .object(let b)):
            return a.count == b.count
                && zip(a, b).allSatisfy { left, right in
                    left.0 == right.0 && left.1 == right.1
                }
        default: return false
        }
    }

    public func first(_ key: String) -> ValveValue? {
        guard case .object(let entries) = self else { return nil }
        return entries.first { $0.0.caseInsensitiveCompare(key) == .orderedSame }?.1
    }

    public var string: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    public var entries: [(String, ValveValue)] {
        if case .object(let value) = self { return value }
        return []
    }
}

public enum ValveKeyValuesError: Error, Equatable, LocalizedError {
    case invalidUTF8
    case unexpectedEnd
    case unexpectedToken(String)
    case trailingContent

    public var errorDescription: String? { "Invalid Steam metadata: \(self)" }
}

public enum ValveKeyValues {
    public static func parse(_ data: Data, maximumBytes: Int = 8 * 1_024 * 1_024) throws -> ValveValue {
        guard data.count <= maximumBytes, let text = String(data: data, encoding: .utf8) else {
            throw ValveKeyValuesError.invalidUTF8
        }
        var parser = Parser(text)
        let entries = try parser.parseEntries(untilBrace: false)
        try parser.ensureFinished()
        return .object(entries)
    }
}

private struct Parser {
    private var scalars: [UnicodeScalar]
    private var index = 0

    init(_ text: String) { scalars = Array(text.unicodeScalars) }

    mutating func parseEntries(untilBrace: Bool) throws -> [(String, ValveValue)] {
        var result: [(String, ValveValue)] = []
        while true {
            skipTrivia()
            if index >= scalars.count {
                if untilBrace { throw ValveKeyValuesError.unexpectedEnd }
                return result
            }
            if scalars[index] == "}" {
                guard untilBrace else { throw ValveKeyValuesError.unexpectedToken("}") }
                index += 1
                return result
            }
            let key = try parseString()
            skipTrivia()
            if index < scalars.count, scalars[index] == "{" {
                index += 1
                result.append((key, .object(try parseEntries(untilBrace: true))))
            } else {
                result.append((key, .string(try parseString())))
            }
        }
    }

    mutating func ensureFinished() throws {
        skipTrivia()
        if index != scalars.count { throw ValveKeyValuesError.trailingContent }
    }

    private mutating func parseString() throws -> String {
        skipTrivia()
        guard index < scalars.count else { throw ValveKeyValuesError.unexpectedEnd }
        if scalars[index] != "\"" {
            let start = index
            while index < scalars.count, !CharacterSet.whitespacesAndNewlines.contains(scalars[index]),
                scalars[index] != "{", scalars[index] != "}"
            { index += 1 }
            guard index > start else { throw ValveKeyValuesError.unexpectedToken(String(scalars[index])) }
            return String(String.UnicodeScalarView(scalars[start..<index]))
        }
        index += 1
        var result = ""
        while index < scalars.count {
            let scalar = scalars[index]
            index += 1
            if scalar == "\"" { return result }
            if scalar == "\\", index < scalars.count {
                let escaped = scalars[index]
                index += 1
                switch escaped {
                case "n": result.append("\n")
                case "r": result.append("\r")
                case "t": result.append("\t")
                default: result.unicodeScalars.append(escaped)
                }
            } else {
                result.unicodeScalars.append(scalar)
            }
        }
        throw ValveKeyValuesError.unexpectedEnd
    }

    private mutating func skipTrivia() {
        while index < scalars.count {
            if CharacterSet.whitespacesAndNewlines.contains(scalars[index]) {
                index += 1
                continue
            }
            if scalars[index] == "/", index + 1 < scalars.count, scalars[index + 1] == "/" {
                index += 2
                while index < scalars.count, scalars[index] != "\n" { index += 1 }
                continue
            }
            break
        }
    }
}
