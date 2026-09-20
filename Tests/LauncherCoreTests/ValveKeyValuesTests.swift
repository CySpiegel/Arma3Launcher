import Foundation
import Testing

@testable import LauncherCore

@Suite struct ValveKeyValuesTests {
    @Test func parsesObjectsCommentsEscapesAndDuplicates() throws {
        let text = #"""
            // header
            "root" { "name" "first" "name" "second" "escaped" "line\nvalue" }
            """#
        let value = try ValveKeyValues.parse(Data(text.utf8))
        let root = try #require(value.first("root"))
        #expect(root.entries.count == 3)
        #expect(root.first("name")?.string == "first")
        #expect(root.first("escaped")?.string == "line\nvalue")
    }

    @Test func rejectsTruncatedObject() {
        #expect(throws: ValveKeyValuesError.unexpectedEnd) {
            try ValveKeyValues.parse(Data(#""root" { "key" "value""#.utf8))
        }
    }

    @Test func rejectsOversizeInput() {
        #expect(throws: ValveKeyValuesError.invalidUTF8) {
            try ValveKeyValues.parse(Data("12345".utf8), maximumBytes: 4)
        }
    }

    @Test func rejectsTrailingBrace() {
        #expect(throws: ValveKeyValuesError.unexpectedToken("}")) {
            try ValveKeyValues.parse(Data("}".utf8))
        }
    }
}
