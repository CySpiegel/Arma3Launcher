import Foundation

public enum ConfigLiteralParser {
    public static func fields(in data: Data, maximumBytes: Int = 1_024 * 1_024) -> [String: String] {
        guard data.count <= maximumBytes, let text = String(data: data, encoding: .utf8) else { return [:] }
        var scanner = Scanner(text)
        return scanner.parse()
    }
}

private struct Scanner {
    let characters: [Character]
    var index = 0

    init(_ text: String) { characters = Array(text) }

    mutating func parse() -> [String: String] {
        var result: [String: String] = [:]
        while index < characters.count {
            skipTrivia()
            guard let key = identifier() else {
                index += 1
                continue
            }
            skipTrivia()
            guard take("=") else { continue }
            skipTrivia()
            guard let value = quotedString() else {
                skipStatement()
                continue
            }
            skipTrivia()
            guard take(";") else { continue }
            result[key.lowercased()] = value
        }
        return result
    }

    private mutating func skipTrivia() {
        while index < characters.count {
            if characters[index].isWhitespace {
                index += 1
                continue
            }
            if matches("//") {
                index += 2
                while index < characters.count, characters[index] != "\n" { index += 1 }
                continue
            }
            if matches("/*") {
                index += 2
                while index + 1 < characters.count, !matches("*/") { index += 1 }
                if index + 1 < characters.count { index += 2 }
                continue
            }
            break
        }
    }

    private mutating func identifier() -> String? {
        let start = index
        while index < characters.count,
            characters[index].isLetter || characters[index].isNumber || characters[index] == "_"
        { index += 1 }
        return index > start ? String(characters[start..<index]) : nil
    }

    private mutating func quotedString() -> String? {
        guard take("\"") else { return nil }
        var result = ""
        while index < characters.count {
            let character = characters[index]
            index += 1
            if character == "\"" { return result }
            if character == "\\", index < characters.count {
                let escaped = characters[index]
                index += 1
                switch escaped {
                case "\"": result.append("\"")
                case "\\": result.append("\\")
                case "n": result.append("\n")
                case "r": result.append("\r")
                case "t": result.append("\t")
                default:
                    result.append("\\")
                    result.append(escaped)
                }
            } else {
                result.append(character)
            }
        }
        return nil
    }

    private mutating func skipStatement() {
        while index < characters.count, characters[index] != ";", characters[index] != "\n" { index += 1 }
        if index < characters.count, characters[index] == ";" { index += 1 }
    }

    private func matches(_ value: String) -> Bool {
        let expected = Array(value)
        guard index + expected.count <= characters.count else { return false }
        return Array(characters[index..<(index + expected.count)]) == expected
    }

    private mutating func take(_ value: Character) -> Bool {
        guard index < characters.count, characters[index] == value else { return false }
        index += 1
        return true
    }
}
