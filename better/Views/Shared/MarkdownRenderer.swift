import SwiftUI
import Foundation

struct MarkdownRenderer: View {
    let text: String

    var body: some View {
        let segments = parseSegments(text)

        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .text(let content):
                    if let attributed = try? AttributedString(
                        markdown: content,
                        options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                    ) {
                        Text(attributed)
                            .textSelection(.enabled)
                    } else {
                        Text(content)
                            .textSelection(.enabled)
                    }

                case .codeBlock(let code, let language):
                    CodeBlockView(code: code, language: language)
                }
            }
        }
    }

    enum Segment {
        case text(String)
        case codeBlock(String, language: String?)
    }

    func parseSegments(_ text: String) -> [Segment] {
        var segments: [Segment] = []
        let pattern = "```(\\w*)\\n([\\s\\S]*?)```"

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
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
