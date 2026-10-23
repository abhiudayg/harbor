import SwiftUI

struct ReaderArticleView: View {
    static let measure: CGFloat = 640

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                meta
                    .padding(.bottom, 14)
                Text("The Architecture of Quiet Interfaces: Why Power Users Crave Visual Restraint")
                    .font(HarborTypography.editorial(size: 34, weight: .medium))
                    .foregroundStyle(HarborColor.onSurface)
                    .fixedSize(horizontal: false, vertical: true)
                byline
                    .padding(.top, 14)
                    .padding(.bottom, 12)
                actions
                    .padding(.bottom, 28)
                body(paragraph: Self.opening)
                body(paragraph: Self.craftsman)
                pullQuote
                body(paragraph: Self.chrome)
                metrics
                body(paragraph: Self.palette)
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
            Text("RESEARCH ARCHIVE")
            Text("·")
            Text("PUBLISHED NOV 14, 2024")
            Text("·")
            Text("9 MIN READ")
        }
        .font(HarborTypography.mono(size: 10, weight: .medium))
        .tracking(1)
        .foregroundStyle(HarborColor.onSurfaceVariant.opacity(0.8))
    }

    private var byline: some View {
        HStack(spacing: 8) {
            Text("Dr. Elena Vance")
            Text("·")
            Text("Reviewed by Systems Guild")
        }
        .font(HarborTypography.chrome(size: 13))
        .foregroundStyle(HarborColor.onSurfaceVariant)
    }

    private var actions: some View {
        HStack(spacing: 6) {
            ForEach(["Save", "Type", "Export"], id: \.self) { title in
                Text(title)
                    .font(HarborTypography.chrome(size: 11, weight: .medium))
                    .foregroundStyle(HarborColor.primary)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(HarborColor.surfaceLowest, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(HarborColor.hairline))
            }
            Spacer()
        }
    }

    private func body(paragraph: String) -> some View {
        Text(paragraph)
            .font(HarborTypography.editorial(size: 18))
            .lineSpacing(7)
            .foregroundStyle(HarborColor.onSurface)
            .padding(.bottom, 22)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var pullQuote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("“Restraint is not the absence of energy; it is the deliberate containment of noise so that signal can resonate without friction.”")
                .font(HarborTypography.editorial(size: 20))
                .italic()
                .foregroundStyle(HarborColor.onSurface)
            Text("— Systems Architecture Monograph, Vol. IV")
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
            metricCard(index: "Metric 01", title: "Cognitive Saccade Latency", lines: ["Baseline: 180ms", "Harbor: 112ms"])
            metricCard(index: "Metric 02", title: "Spatial Working Memory", lines: ["Retention rate", "94.2% stability"])
        }
        .padding(.bottom, 22)
    }

    private func metricCard(index: String, title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(index.uppercased())
                .font(HarborTypography.mono(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundStyle(HarborColor.primary)
            Text(title)
                .font(HarborTypography.chrome(size: 13, weight: .semibold))
                .foregroundStyle(HarborColor.onSurface)
            ForEach(lines, id: \.self) { line in
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
            Text("ergonomics.config.ts · TypeScript")
                .font(HarborTypography.mono(size: 10, weight: .medium))
                .foregroundStyle(HarborColor.onSurfaceVariant)
            Text("interface ViewportConstraint { maxLine: \"68ch\"; divider: \"hairline-1px\"; shadows: false; accent: \"#b45309\"; success: \"#005823\"; error: \"#ba1a1a\"; }")
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
        Text("[1] The Disappearance of the Browser Frame")
            .font(HarborTypography.mono(size: 11))
            .foregroundStyle(HarborColor.onSurfaceVariant)
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
            Text("Next in queue: The Disappearance of the Browser Frame")
                .font(HarborTypography.chrome(size: 12))
                .foregroundStyle(HarborColor.onSurfaceVariant)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HarborColor.surfaceLowest, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(HarborColor.hairline))
    }

    static let opening = "Every decorative flourish introduced to a technical application carries a persistent thermodynamic cognitive tax. When an interface relies on vibrating gradients, erratic multi-tiered elevation shadows, and unmetered notifications, the user's executive function spends precious working memory constantly parsing chrome rather than processing thought."

    static let craftsman = "The ethos of desktop computing has drifted toward superficial theatrics. Yet the master craftsman’s bench is not lined with polished brass or mirrored chrome; it is constructed of dense, oiled birch, marked only by hairline measurements and functional recesses where tools can rest without slipping."

    static let chrome = "In Harbor, depth is never faked with sprawling blurred drop shadows. Boundaries are established exclusively through tonal stepping and physical single-pixel hairlines. When visual divisions are predictable and razor-sharp, the eye traverses workspaces with zero hesitation."

    static let palette = "By restricting the visual spectrum to a foundational warm paper neutral, a deliberate harbor teal accent, and purposeful semantic state indicators, the screen recedes entirely into the periphery. The user ceases to look at the browser; they think directly through the document."
}
