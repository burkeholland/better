import SwiftUI
import Foundation

struct MarkdownRenderer: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .text(let content):
                    MarkdownBlockRenderer(text: content)

                case .codeBlock(let code, let language):
                    CodeBlockView(code: code, language: language)
                }
            }
        }
    }

    // Cache parse result — only recomputed when `text` changes
    private var segments: [Segment] {
        Self.parseSegments(text)
    }

    enum Segment {
        case text(String)
        case codeBlock(String, language: String?)
    }

    private static let codeBlockRegex = try? NSRegularExpression(pattern: "```(\\w*)\\n([\\s\\S]*?)```")

    static func parseSegments(_ text: String) -> [Segment] {
        var segments: [Segment] = []

        guard let regex = codeBlockRegex else {
            return [.text(text)]
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        var lastEnd = 0

        for match in matches {
            let matchRange = match.range

            if matchRange.location > lastEnd {
                let before = nsText
                    .substring(with: NSRange(location: lastEnd, length: matchRange.location - lastEnd))
                    .trimmingCharacters(in: .newlines)
                if !before.isEmpty {
                    segments.append(.text(before))
                }
            }

            let langRange = match.range(at: 1)
            let language = langRange.length > 0 ? nsText.substring(with: langRange) : nil

            let codeRange = match.range(at: 2)
            let code = nsText.substring(with: codeRange)
                .trimmingCharacters(in: .newlines)

            segments.append(.codeBlock(code, language: language))

            lastEnd = matchRange.location + matchRange.length
        }

        if lastEnd < nsText.length {
            let remaining = nsText.substring(from: lastEnd)
                .trimmingCharacters(in: .newlines)
            if !remaining.isEmpty {
                segments.append(.text(remaining))
            }
        }

        if segments.isEmpty {
            segments.append(.text(text))
        }

        return segments
    }
}

// MARK: - Block-Level Markdown Renderer

struct MarkdownBlockRenderer: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
    }

    private var blocks: [Block] {
        Self.parseBlocks(text)
    }

    enum Block {
        case paragraph(String)
        case heading(Int, String)           // level 1-6, content
        case unorderedList([String])        // list items
        case orderedList([String])          // list items
        case blockquote(String)
        case horizontalRule
    }

    @ViewBuilder
    private func renderBlock(_ block: Block) -> some View {
        switch block {
        case .paragraph(let content):
            renderInlineMarkdown(content)
                .textSelection(.enabled)

        case .heading(let level, let content):
            renderInlineMarkdown(content)
                .font(fontForHeading(level))
                .fontWeight(.semibold)
                .textSelection(.enabled)
                .padding(.top, level <= 2 ? 4 : 2)

        case .unorderedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•")
                            .foregroundStyle(Theme.charcoal.opacity(0.6))
                        renderInlineMarkdown(item)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(.leading, 4)

        case .orderedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(index + 1).")
                            .foregroundStyle(Theme.charcoal.opacity(0.6))
                            .frame(minWidth: 20, alignment: .trailing)
                        renderInlineMarkdown(item)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(.leading, 4)

        case .blockquote(let content):
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.lavender.opacity(0.5))
                    .frame(width: 3)
                renderInlineMarkdown(content)
                    .foregroundStyle(Theme.charcoal.opacity(0.8))
                    .italic()
                    .textSelection(.enabled)
                    .padding(.leading, 12)
            }
            .padding(.vertical, 4)

        case .horizontalRule:
            Divider()
                .padding(.vertical, 8)
        }
    }

    private func fontForHeading(_ level: Int) -> Font {
        switch level {
        case 1: return .title2
        case 2: return .title3
        case 3: return .headline
        default: return .subheadline
        }
    }

    @ViewBuilder
    private func renderInlineMarkdown(_ content: String) -> some View {
        if let attributed = try? AttributedString(
            markdown: content,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            Text(attributed)
        } else {
            Text(content)
        }
    }

    private static func parseBlocks(_ text: String) -> [Block] {
        var blocks: [Block] = []
        let lines = text.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines
            if trimmed.isEmpty {
                i += 1
                continue
            }

            // Horizontal rule: ---, ***, ___
            if trimmed.allSatisfy({ $0 == "-" || $0 == "*" || $0 == "_" }) && trimmed.count >= 3 {
                let uniqueChars = Set(trimmed)
                if uniqueChars.count == 1 {
                    blocks.append(.horizontalRule)
                    i += 1
                    continue
                }
            }

            // Heading: # ## ### etc
            if let match = trimmed.prefixMatch(of: /^(#{1,6})\s+(.+)$/) {
                let level = match.1.count
                let content = String(match.2)
                blocks.append(.heading(level, content))
                i += 1
                continue
            }

            // Blockquote: > text
            if trimmed.hasPrefix(">") {
                var quoteLines: [String] = []
                while i < lines.count {
                    let qLine = lines[i].trimmingCharacters(in: .whitespaces)
                    if qLine.hasPrefix(">") {
                        let content = String(qLine.dropFirst()).trimmingCharacters(in: .whitespaces)
                        quoteLines.append(content)
                        i += 1
                    } else if qLine.isEmpty && !quoteLines.isEmpty {
                        i += 1
                        break
                    } else {
                        break
                    }
                }
                blocks.append(.blockquote(quoteLines.joined(separator: " ")))
                continue
            }

            // Unordered list: - or * or +
            if trimmed.prefixMatch(of: /^[-*+]\s+/) != nil {
                var items: [String] = []
                while i < lines.count {
                    let listLine = lines[i].trimmingCharacters(in: .whitespaces)
                    if let match = listLine.prefixMatch(of: /^[-*+]\s+(.*)$/) {
                        items.append(String(match.1))
                        i += 1
                    } else if listLine.isEmpty && !items.isEmpty {
                        // Allow one empty line between items
                        if i + 1 < lines.count {
                            let nextLine = lines[i + 1].trimmingCharacters(in: .whitespaces)
                            if nextLine.prefixMatch(of: /^[-*+]\s+/) != nil {
                                i += 1
                                continue
                            }
                        }
                        break
                    } else {
                        break
                    }
                }
                if !items.isEmpty {
                    blocks.append(.unorderedList(items))
                }
                continue
            }

            // Ordered list: 1. 2. etc
            if trimmed.prefixMatch(of: /^\d+\.\s+/) != nil {
                var items: [String] = []
                while i < lines.count {
                    let listLine = lines[i].trimmingCharacters(in: .whitespaces)
                    if let match = listLine.prefixMatch(of: /^\d+\.\s+(.*)$/) {
                        items.append(String(match.1))
                        i += 1
                    } else if listLine.isEmpty && !items.isEmpty {
                        if i + 1 < lines.count {
                            let nextLine = lines[i + 1].trimmingCharacters(in: .whitespaces)
                            if nextLine.prefixMatch(of: /^\d+\.\s+/) != nil {
                                i += 1
                                continue
                            }
                        }
                        break
                    } else {
                        break
                    }
                }
                if !items.isEmpty {
                    blocks.append(.orderedList(items))
                }
                continue
            }

            // Regular paragraph - collect consecutive non-block lines
            var paragraphLines: [String] = []
            while i < lines.count {
                let pLine = lines[i]
                let pTrimmed = pLine.trimmingCharacters(in: .whitespaces)

                // Stop if we hit another block element
                if pTrimmed.isEmpty ||
                    pTrimmed.hasPrefix("#") ||
                    pTrimmed.hasPrefix(">") ||
                    pTrimmed.prefixMatch(of: /^[-*+]\s+/) != nil ||
                    pTrimmed.prefixMatch(of: /^\d+\.\s+/) != nil ||
                    (pTrimmed.allSatisfy({ $0 == "-" || $0 == "*" || $0 == "_" }) && pTrimmed.count >= 3) {
                    break
                }

                paragraphLines.append(pTrimmed)
                i += 1
            }

            if !paragraphLines.isEmpty {
                blocks.append(.paragraph(paragraphLines.joined(separator: " ")))
            }
        }

        return blocks
    }
}
