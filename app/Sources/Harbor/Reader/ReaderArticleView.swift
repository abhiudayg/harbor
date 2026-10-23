import AppKit
import SwiftUI

struct ReaderArticleView: View {
    private let article = ReaderArticle.cognitiveErgonomics
    @State private var isSaved = false
    @State private var isLargeType = false
    @State private var didExport = false

    private var bodySize: CGFloat {
        isLargeType ? 18 : 16
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header
                    .padding(32)
                    .glassCard(cornerRadius: 20)
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(Array(article.blocks.enumerated()), id: \.offset) { item in
                        blockView(item.element)
                    }
                }
                .padding(32)
                .glassCard(cornerRadius: 20)
                readingFooter
            }
            .frame(maxWidth: 768, alignment: .leading)
            .padding(.horizontal, 64)
            .padding(.top, 32)
            .padding(.bottom, 48)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.never)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Text(article.kicker.uppercased())
                    Text("/")
                    Text(article.section.uppercased())
                        .foregroundStyle(HarborColor.primary)
                        .fontWeight(.medium)
                }
                .font(HarborTypography.text(size: 11))
                .tracking(0.55)
                .foregroundStyle(HarborColor.outline)
                Spacer()
                HStack(spacing: 12) {
                    Text(article.published)
                        .font(HarborTypography.text(size: 11))
                        .foregroundStyle(HarborColor.outline)
                    Circle()
                        .fill(HarborColor.outlineVariant)
                        .frame(width: 4, height: 4)
                    Text(article.readingTime)
                        .font(HarborTypography.text(size: 11))
                        .foregroundStyle(HarborColor.onSurfaceVariant)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(HarborColor.surfaceContainerLow, in: RoundedRectangle(cornerRadius: 4))
                }
            }
            Text(article.title)
                .font(HarborTypography.headline(size: 28, weight: .semibold))
                .tracking(-0.4)
                .lineSpacing(3)
                .foregroundStyle(HarborColor.primary)
                .fixedSize(horizontal: false, vertical: true)
            byline
                .padding(.top, 8)
        }
        .padding(.bottom, 24)
        .overlay(alignment: .bottom) {
            Divider().overlay(HarborColor.outlineVariant)
        }
    }

    private var byline: some View {
        HStack(spacing: 12) {
            Text("EV")
                .font(HarborTypography.text(size: 11, weight: .semibold))
                .foregroundStyle(HarborColor.primary)
                .frame(width: 28, height: 28)
                .background(HarborColor.surfaceContainer, in: Circle())
                .overlay(Circle().stroke(HarborColor.outlineVariant))
            (Text("By ")
                + Text(article.author).fontWeight(.medium).foregroundColor(HarborColor.onSurface)
                + Text(" · Reviewed by ")
                + Text(article.reviewer).italic())
                .font(HarborTypography.text(size: 13))
                .foregroundStyle(HarborColor.onSurfaceVariant)
            Spacer()
            HStack(spacing: 6) {
                actionButton(isSaved ? "Saved" : "Save", symbol: isSaved ? "bookmark" : "bookmark") {
                    isSaved.toggle()
                }
                actionButton("Type", symbol: "text_fields") {
                    isLargeType.toggle()
                }
                actionButton(didExport ? "Copied" : "Export", symbol: "share") {
                    export()
                }
            }
        }
    }

    private func actionButton(_ title: String, symbol: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            HStack(spacing: 4) {
                MaterialIcon(symbol)
                    .font(.system(size: 13))
                Text(title)
                    .font(HarborTypography.text(size: 11, weight: .medium))
            }
            .foregroundStyle(HarborColor.outline)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(HarborColor.surfaceLowest, in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(HarborColor.outlineVariant))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func export() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(article.plainText, forType: .string)
        didExport = true
    }

    @ViewBuilder
    private func blockView(_ block: ReaderArticle.Block) -> some View {
        switch block {
        case .dropCap(let text):
            dropCapParagraph(text)
        case .paragraph(let text):
            paragraph(text)
        case .pullQuote(let text, let source):
            pullQuote(text: text, source: source)
        case .heading(let text):
            heading(text)
        case .metrics(let metrics):
            metricsGrid(metrics)
        case .code(let code):
            codeBlock(code)
        case .footnote(let note):
            footnote(note)
        }
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(HarborTypography.text(size: bodySize))
            .lineSpacing(bodySize * 0.55)
            .foregroundStyle(HarborColor.onSurface)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dropCapParagraph(_ text: String) -> some View {
        let first = String(text.prefix(1))
        let rest = String(text.dropFirst())
        return HStack(alignment: .top, spacing: 8) {
            Text(first)
                .font(HarborTypography.text(size: 36, weight: .semibold))
                .foregroundStyle(HarborColor.primary)
            Text(rest)
                .font(HarborTypography.text(size: 16))
                .lineSpacing(7)
                .foregroundStyle(HarborColor.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func pullQuote(text: String, source: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("“\(text)”")
                .font(HarborTypography.headline(size: 16, weight: .semibold))
                .italic()
                .lineSpacing(3)
                .foregroundStyle(HarborColor.onSurface)
            Text("— \(source)".uppercased())
                .font(HarborTypography.text(size: 11))
                .tracking(0.55)
                .foregroundStyle(HarborColor.outline)
        }
        .padding(.leading, 16)
        .padding(.trailing, 16)
        .padding(.vertical, 12)
        .background(HarborColor.surface)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(HarborColor.primary)
                .frame(width: 2)
        }
        .padding(.vertical, 8)
    }

    private func heading(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().overlay(HarborColor.outlineVariant)
            Text(text)
                .font(HarborTypography.headline(size: 18, weight: .semibold))
                .foregroundStyle(HarborColor.onSurface)
                .padding(.top, 16)
        }
    }

    private func metricsGrid(_ metrics: [ReaderArticle.Metric]) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ForEach(metrics) { metric in
                metricCard(metric)
            }
        }
    }

    private func metricCard(_ metric: ReaderArticle.Metric) -> some View {
        let tone = metric.tone == .accent ? HarborColor.primary : HarborColor.metricPositive
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(metric.index.uppercased())
                    .font(HarborTypography.text(size: 11))
                    .tracking(0.55)
                    .foregroundStyle(HarborColor.outline)
                Spacer()
                Circle()
                    .fill(metric.tone == .accent ? HarborColor.primaryContainer : HarborColor.metricPositive)
                    .frame(width: 8, height: 8)
            }
            Text(metric.title)
                .font(HarborTypography.headline(size: 15, weight: .semibold))
                .foregroundStyle(HarborColor.onSurface)
            Text(metric.detail)
                .font(HarborTypography.text(size: 13))
                .lineSpacing(4)
                .foregroundStyle(HarborColor.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 0) {
                Divider().overlay(HarborColor.outlineVariant)
                HStack {
                    Text(metric.baselineLabel)
                        .foregroundStyle(HarborColor.outline)
                    Spacer()
                    Text(metric.baseline)
                        .fontWeight(.semibold)
                        .foregroundStyle(tone)
                }
                .padding(.top, 8)
            }
            .font(HarborTypography.text(size: 11))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HarborColor.surfaceContainerLow, in: RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(HarborColor.outlineVariant))
    }

    private func codeBlock(_ code: ReaderArticle.CodeBlock) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                MaterialIcon("data_object", size: 12)
                    .foregroundStyle(HarborColor.outline)
                Text(code.fileName)
                    .font(HarborTypography.text(size: 11))
                    .foregroundStyle(HarborColor.onSurface)
                Spacer()
                Text(code.language)
                    .font(HarborTypography.text(size: 11))
                    .foregroundStyle(HarborColor.outline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(HarborColor.surfaceContainerLow)
            Divider().overlay(HarborColor.outlineVariant)
            codeLines(code.lines)
                .font(HarborTypography.text(size: 11))
                .lineSpacing(3.9)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(HarborColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(HarborColor.outlineVariant))
    }

    private func codeLines(_ lines: [[ReaderArticle.CodeToken]]) -> Text {
        lines.enumerated().reduce(Text("")) { result, indexed in
            let line = indexed.element.reduce(Text("")) { $0 + codeText($1) }
            let separator = indexed.offset == 0 ? Text("") : Text("\n")
            return result + separator + line
        }
    }

    private func codeText(_ token: ReaderArticle.CodeToken) -> Text {
        let text = Text(token.text).foregroundColor(color(for: token.role))
        return token.role == .name ? text.fontWeight(.semibold) : text
    }

    private func color(for role: ReaderArticle.CodeRole) -> Color {
        switch role {
        case .plain: HarborColor.onSurface
        case .keyword, .literal: HarborColor.primary
        case .name: HarborColor.onSurface
        case .string: HarborColor.codeString
        case .approval: HarborColor.approvalAction
        case .completed: HarborColor.tertiaryGreen
        case .failed: HarborColor.error
        }
    }

    private func footnote(_ note: ReaderArticle.Footnote) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("[\(note.number)]")
                .font(HarborTypography.text(size: 11))
                .foregroundStyle(HarborColor.outline)
                .padding(.horizontal, 4)
                .background(HarborColor.surface, in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(HarborColor.outlineVariant))
            (Text(note.lead)
                + Text(note.title).italic().foregroundColor(HarborColor.onSurface)
                + Text(note.trail))
                .font(HarborTypography.text(size: 13))
                .foregroundStyle(HarborColor.onSurfaceVariant)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(HarborColor.surfaceContainerLow, in: RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(HarborColor.outlineVariant))
    }

    private var readingFooter: some View {
        HStack {
            HStack(spacing: 8) {
                MaterialIcon("check_circle", size: 14)
                    .foregroundStyle(HarborColor.outline)
                Text("Completed reading · Automatically archived")
            }
            Spacer()
            HStack(spacing: 12) {
                Text("Next in queue:")
                    .foregroundStyle(HarborColor.outline)
                HStack(spacing: 4) {
                    Text(article.nextInQueue)
                        .fontWeight(.medium)
                    MaterialIcon("arrow_forward", size: 11)
                }
                .foregroundStyle(HarborColor.primary)
            }
        }
        .font(HarborTypography.text(size: 13))
        .foregroundStyle(HarborColor.onSurfaceVariant)
        .padding(.top, 32)
        .overlay(alignment: .top) {
            Divider().overlay(HarborColor.outlineVariant)
        }
    }
}
