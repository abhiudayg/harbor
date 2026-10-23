import Testing
@testable import Harbor

@Suite("Reader article")
struct ReaderArticleTests {
    @Test("export text starts with the title and includes the body text in reading order")
    func plainTextMatchesTheRenderedArticle() {
        let article = ReaderArticle.cognitiveErgonomics

        let parts = article.plainText.components(separatedBy: "\n\n")

        #expect(parts.first == article.title)
        #expect(parts.contains { $0.hasPrefix("Every decorative flourish") })
        #expect(parts.contains("1. Spatial Discipline & The 1px Hairline"))
        #expect(parts.contains { $0.hasPrefix("Cognitive Saccade Latency") })
    }

    @Test("footnotes come from the article so citations match the text")
    func footnotesComeFromTheArticle() {
        #expect(ReaderArticle.cognitiveErgonomics.footnotes.map(\.title) == ["The Disappearance of the Browser Frame"])
    }
}
