import AppKit
import SwiftUI

struct ReaderArticleView: View {
    static let measure: CGFloat = 640

    private let article = ReaderArticle.cognitiveErgonomics
    @State private var isSaved = false
    @State private var usesSansBody = false
    @State private var didExport = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                meta
                    .padding(.bottom, 14)
                Text(article.title)
                    .font(HarborTypography.editorial(size: 34, weight: .medium))
                    .foregroundStyle(HarborColor.onSurface)
                    .fixedSize(horizontal: false, vertical: true)
                byline
                    .padding(.top, 14)
                    .padding(.bottom, 12)
                actions
                    .padding(.bottom, 28)
                ForEach(article.paragraphs, id: \.self) { paragraph in
                    body(paragraph: paragraph)
                }
                pullQuote
                metrics
                codeBlock
                footnote
                readingFooter
            }
            .frame(maxWidth: Self.measure, alignment: .leading)
            .padding(.horizontal, 40)
            .padding(.vertical, 40)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.never)
        .background(HarborColor.surface)
    }

    private var meta: some View {
        HStack(spacing: 8) {
            Text(article.kicker.uppercased())
            Text("·")
            Text(article.published.uppercased())
            Text("·")
            Text(article.readingTime.uppercased())
        }
        .font(HarborTypography.mono(size: 10, weight: .medium))
        .tracking(1)
        .foregroundStyle(HarborColor.onSurfaceVariant.opacity(0.8))
    }

    private var byline: some View {
        HStack(spacing: 8) {
            Text(article.author)
            Text("·")
            Text("Reviewed by \(article.reviewer)")
        }
        .font(HarborTypography.chrome(size: 13))
        .foregroundStyle(HarborColor.onSurfaceVariant)
    }

    private var actions: some View {
        HStack(spacing: 6) {
            actionButton(isSaved ? "Saved" : "Save") { isSaved.toggle() }
            actionButton("Type") { usesSansBody.toggle() }
            actionButton(didExport ? "Copied" : "Export") { export() }
            Spacer()
        }
    }

    private func actionButton(_ title: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Text(title)
                .font(HarborTypography.chrome(size: 11, weight: .medium))
                .foregroundStyle(HarborColor.primary)
                .padding(.horizontal, 8)
                .frame(height: 24)
                .background(HarborColor.surfaceLowest, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(HarborColor.hairline))
        }
        .buttonStyle(.plain)
    }

    private func export() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(article.plainText, forType: .string)
        didExport = true
    }

    private func body(paragraph: String) -> some View {
        Text(paragraph)
            .font(usesSansBody ? HarborTypography.chrome(size: 16) : HarborTypography.editorial(size: 18))
            .lineSpacing(7)
            .foregroundStyle(HarborColor.onSurface)
            .padding(.bottom, 22)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var pullQuote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("“\(article.pullQuote)”")
                .font(HarborTypography.editorial(size: 20))
                .italic()
                .foregroundStyle(HarborColor.onSurface)
            Text("— \(article.pullQuoteSource)")
                .font(HarborTypography.mono(size: 11))
                .foregroundStyle(HarborColor.onSurfaceVariant)
        }
        .padding(.leading, 18)
        .padding(.vertical, 6)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(HarborColor.accentTeal)
                .frame(width: 2)
        }
        .padding(.vertical, 12)
    }

    private var metrics: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(article.metrics) { metric in
                metricCard(metric)
            }
        }
        .padding(.bottom, 22)
    }

    private func metricCard(_ metric: ReaderArticle.Metric) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(metric.index.uppercased())
                .font(HarborTypography.mono(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundStyle(HarborColor.primary)
            Text(metric.title)
                .font(HarborTypography.chrome(size: 13, weight: .semibold))
                .foregroundStyle(HarborColor.onSurface)
            ForEach(metric.lines, id: \.self) { line in
                Text(line)
                    .font(HarborTypography.chrome(size: 12))
                    .foregroundStyle(HarborColor.onSurfaceVariant)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HarborColor.surfaceLowest, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(HarborColor.hairline))
    }

    private var codeBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(article.codeCaption)
                .font(HarborTypography.mono(size: 10, weight: .medium))
                .foregroundStyle(HarborColor.onSurfaceVariant)
            Text(article.codeSample)
                .font(HarborTypography.mono(size: 11))
                .foregroundStyle(HarborColor.onSurface)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HarborColor.surfaceContainer, in: RoundedRectangle(cornerRadius: 8))
        .padding(.bottom, 22)
    }

    private var footnote: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(article.footnotes.enumerated()), id: \.offset) { index, note in
                Text("[\(index + 1)] \(note)")
                    .font(HarborTypography.mono(size: 11))
                    .foregroundStyle(HarborColor.onSurfaceVariant)
            }
        }
        .padding(.bottom, 16)
    }

    private var readingFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(HarborColor.tertiaryGreen)
                Text("Completed reading · Automatically archived")
                    .font(HarborTypography.chrome(size: 12, weight: .medium))
                    .foregroundStyle(HarborColor.onSurface)
            }
            Text("Next in queue: \(article.nextInQueue)")
                .font(HarborTypography.chrome(size: 12))
                .foregroundStyle(HarborColor.onSurfaceVariant)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HarborColor.surfaceLowest, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(HarborColor.hairline))
    }
}
