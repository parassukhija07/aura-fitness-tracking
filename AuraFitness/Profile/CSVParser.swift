import Foundation

/// Minimal RFC-4180 CSV parser. Pure, no I/O, unit-testable. Handles quoted
/// fields, embedded commas/newlines, and doubled-quote escaping — the exact
/// inverse of `CSVArchiveBuilder.csvField(_:)`.
enum CSVParser {
    enum CSVError: Error { case malformed(line: Int) }

    /// Returns rows of fields. First row is the header. Throws on malformed
    /// quoting (an unterminated quoted field at end of input).
    static func parse(_ text: String) throws -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var field = ""
        var inQuotes = false
        var line = 1

        let chars = Array(text)
        var i = 0
        let count = chars.count

        func endField() {
            currentRow.append(field)
            field = ""
        }
        func endRow() {
            endField()
            rows.append(currentRow)
            currentRow = []
        }

        while i < count {
            let c = chars[i]

            if inQuotes {
                if c == "\"" {
                    // Doubled quote inside a quoted field -> literal quote.
                    if i + 1 < count, chars[i + 1] == "\"" {
                        field.append("\"")
                        i += 2
                        continue
                    } else {
                        inQuotes = false
                        i += 1
                        continue
                    }
                } else {
                    if c == "\n" { line += 1 }
                    field.append(c)
                    i += 1
                    continue
                }
            } else {
                switch c {
                case "\"":
                    inQuotes = true
                    i += 1
                case ",":
                    endField()
                    i += 1
                case "\r":
                    // Swallow bare CR; CRLF handled by the following \n case.
                    i += 1
                case "\n":
                    line += 1
                    endRow()
                    i += 1
                default:
                    field.append(c)
                    i += 1
                }
            }
        }

        if inQuotes {
            throw CSVError.malformed(line: line)
        }

        // Trailing field/row (file may or may not end with a newline).
        if !field.isEmpty || !currentRow.isEmpty {
            endRow()
        }

        return rows
    }
}
