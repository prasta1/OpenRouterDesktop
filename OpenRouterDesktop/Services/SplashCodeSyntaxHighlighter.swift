import SwiftUI
import MarkdownUI
import Splash

/// Bridges Splash (Swift-only syntax highlighter) into swift-markdown-ui's `CodeSyntaxHighlighter`
/// protocol. Swift code blocks get colorized; everything else falls through to plain monospace.
struct SplashCodeSyntaxHighlighter: CodeSyntaxHighlighter {
    private let highlighter: SyntaxHighlighter<TextOutputFormat>

    init(theme: Splash.Theme) {
        self.highlighter = SyntaxHighlighter(format: TextOutputFormat(theme: theme))
    }

    func highlightCode(_ content: String, language: String?) -> Text {
        guard let language, language.lowercased() == "swift" else {
            return Text(content)
        }
        return highlighter.highlight(content)
    }
}

extension CodeSyntaxHighlighter where Self == SplashCodeSyntaxHighlighter {
    static var swiftHighlighter: Self {
        SplashCodeSyntaxHighlighter(
            theme: .sundellsColors(withFont: Splash.Font(size: 13))
        )
    }
}

/// Splash output format that produces a SwiftUI `Text` view, colorized per Splash theme.
struct TextOutputFormat: OutputFormat {
    private let theme: Splash.Theme

    init(theme: Splash.Theme) {
        self.theme = theme
    }

    func makeBuilder() -> Builder {
        Builder(theme: theme)
    }
}

extension TextOutputFormat {
    struct Builder: OutputBuilder {
        private let theme: Splash.Theme
        private var accumulated: [Text] = []

        init(theme: Splash.Theme) {
            self.theme = theme
        }

        mutating func addToken(_ token: String, ofType type: TokenType) {
            let nsColor = theme.tokenColors[type] ?? theme.plainTextColor
            accumulated.append(Text(token).foregroundColor(Color(nsColor: nsColor)))
        }

        mutating func addPlainText(_ text: String) {
            accumulated.append(
                Text(text).foregroundColor(Color(nsColor: theme.plainTextColor))
            )
        }

        mutating func addWhitespace(_ whitespace: String) {
            accumulated.append(Text(whitespace))
        }

        func build() -> Text {
            accumulated.reduce(Text(""), +)
        }
    }
}
