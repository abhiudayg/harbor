import Testing
@testable import Harbor

@Suite("Reader article")
struct ReaderArticleTests {
    @Test("export text carries the title and every paragraph in reading order")
    func plainTextMatchesTheRenderedArticle() {
        let article = ReaderArticle.cognitiveErgonomics

        let lines = article.plainText.components(separatedBy: "\n\n")

        #expect(lines.first == article.title)
        #expect(Array(lines.dropFirst()) == article.paragraphs)
    }

    @Test("citations come from the article footnotes")
    func footnotesAreNonEmptyForTheSampleArticle() {
        #expect(ReaderArticle.cognitiveErgonomics.footnotes == ["The Disappearance of the Browser Frame"])
    }
}
