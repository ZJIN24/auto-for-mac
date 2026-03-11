import Foundation

struct PythonLikeTranspiler {
    func transpile(_ source: String) throws -> String {
        var output: [String] = []
        var blockIndentStack: [Int] = []
        let lines = source.replacingOccurrences(of: "\t", with: "    ").components(separatedBy: .newlines)

        for (index, rawLine) in lines.enumerated() {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                output.append("")
                continue
            }

            if trimmed.hasPrefix("#") {
                output.append("// " + trimmed.dropFirst())
                continue
            }

            let indent = rawLine.prefix { $0 == " " }.count
            let isElseChain = trimmed == "else:" || trimmed.hasPrefix("elif ")

            while let lastIndent = blockIndentStack.last, indent <= lastIndent {
                output.append(String(repeating: " ", count: max(lastIndent, 0)) + "}")
                blockIndentStack.removeLast()
                if isElseChain { break }
            }

            if trimmed == "else:" {
                guard indent >= 0 else {
                    throw StudioError.scriptError("第 \(index + 1) 行 else 缩进错误")
                }
                output.append(String(repeating: " ", count: indent) + "else {")
                blockIndentStack.append(indent)
                continue
            }

            if trimmed.hasPrefix("elif ") {
                let condition = normalizeExpression(String(trimmed.dropFirst(5).dropLast()))
                output.append(String(repeating: " ", count: indent) + "else if (\(condition)) {")
                blockIndentStack.append(indent)
                continue
            }

            if trimmed.hasSuffix(":") {
                let statement = String(trimmed.dropLast())
                let block = try openBlock(from: statement, line: index + 1)
                output.append(String(repeating: " ", count: indent) + block)
                blockIndentStack.append(indent)
                continue
            }

            output.append(String(repeating: " ", count: indent) + convertStatement(trimmed) + ";")
        }

        while let lastIndent = blockIndentStack.last {
            output.append(String(repeating: " ", count: max(lastIndent, 0)) + "}")
            blockIndentStack.removeLast()
        }

        return output.joined(separator: "\n")
    }

    private func openBlock(from statement: String, line: Int) throws -> String {
        if statement.hasPrefix("def ") {
            let body = statement.dropFirst(4)
            return "function \(body) {"
        }
        if statement.hasPrefix("if ") {
            return "if (\(normalizeExpression(String(statement.dropFirst(3))))) {"
        }
        if statement.hasPrefix("while ") {
            return "while (\(normalizeExpression(String(statement.dropFirst(6))))) {"
        }
        if statement.hasPrefix("for ") {
            return try convertForLoop(statement, line: line)
        }
        throw StudioError.scriptError("第 \(line) 行暂不支持的语法：\(statement)")
    }

    private func convertForLoop(_ statement: String, line: Int) throws -> String {
        let pattern = /^for\s+([A-Za-z_][A-Za-z0-9_]*)\s+in\s+range\((.*)\)$/
        guard let match = statement.firstMatch(of: pattern) else {
            throw StudioError.scriptError("第 \(line) 行 for 语法只支持 range()")
        }

        let variable = String(match.1)
        let rawArguments = String(match.2)
        let arguments = rawArguments.split(separator: ",").map { normalizeExpression($0.trimmingCharacters(in: .whitespaces)) }

        switch arguments.count {
        case 1:
            return "for (let \(variable) = 0; \(variable) < \(arguments[0]); \(variable) += 1) {"
        case 2:
            return "for (let \(variable) = \(arguments[0]); \(variable) < \(arguments[1]); \(variable) += 1) {"
        case 3:
            let step = arguments[2]
            let comparator = step.hasPrefix("-") ? ">" : "<"
            return "for (let \(variable) = \(arguments[0]); \(variable) \(comparator) \(arguments[1]); \(variable) += \(step)) {"
        default:
            throw StudioError.scriptError("第 \(line) 行 range 参数数量不正确")
        }
    }

    private func convertStatement(_ trimmed: String) -> String {
        if trimmed == "pass" {
            return ""
        }
        if trimmed == "break" || trimmed == "continue" {
            return trimmed
        }
        if trimmed.hasPrefix("return") {
            return normalizeExpression(trimmed)
        }
        return normalizeExpression(trimmed)
    }

    private func normalizeExpression(_ expression: String) -> String {
        var value = expression
        let replacements = [
            (#"\bTrue\b"#, "true"),
            (#"\bFalse\b"#, "false"),
            (#"\bNone\b"#, "null"),
            (#"\band\b"#, "&&"),
            (#"\bor\b"#, "||")
        ]

        for (pattern, replacement) in replacements {
            value = value.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }

        value = value.replacingOccurrences(of: #"\bnot\s+"#, with: "!", options: .regularExpression)
        return value
    }
}
