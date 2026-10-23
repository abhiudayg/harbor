import SwiftUI

struct ReaderArticleView: View {
    static let measure: CGFloat = 640

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                meta
                    .padding(.bottom, 14)
                Text("The Architecture of Open Systems: Resilience Through Modularity")
                    .font(HarborTypography.editorial(size: 36, weight: .medium))
                    .foregroundStyle(HarborColor.onSurface)
                    .fixedSize(horizontal: false, vertical: true)
                byline
                    .padding(.top, 14)
                    .padding(.bottom, 28)
                body(paragraph: Self.opening)
                body(paragraph: Self.unixStance)
                pullQuote
                body(paragraph: Self.consensus)
                annotation
                body(paragraph: Self.storage)
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
            Text("SYSTEMS ARCHITECTURE")
            Text("·")
            Text("ESSAY NO. 4")
            Text("·")
            Text("12 MIN READ")
        }
        .font(HarborTypography.mono(size: 10, weight: .medium))
        .tracking(1)
        .foregroundStyle(HarborColor.onSurfaceVariant.opacity(0.8))
    }

    private var byline: some View {
        HStack(spacing: 8) {
            Text("By Elena Vance")
            Text("·")
            Text("Published March 2025")
        }
        .font(HarborTypography.chrome(size: 13))
        .foregroundStyle(HarborColor.onSurfaceVariant)
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
            Text("“A system achieves true resilience not when components cannot fail, but when any single failure provides unambiguous diagnostic telemetry to its immediate peers without stalling the collective pipeline.”")
                .font(HarborTypography.editorial(size: 20))
                .italic()
                .foregroundStyle(HarborColor.onSurface)
            Text("— § 3.2 Post-Failure Topology Guarantees")
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

    private var annotation: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Annotated note")
                .font(HarborTypography.chrome(size: 11, weight: .semibold))
                .foregroundStyle(HarborColor.approvalText)
            Text("Cross-reference with Martin Kleppmann’s recent synthesis on local-first software models and Byzantine state reconciliation.")
                .font(HarborTypography.chrome(size: 13))
                .foregroundStyle(HarborColor.onSurfaceVariant)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HarborColor.approvalFill, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(HarborColor.approvalBorder))
        .padding(.bottom, 22)
    }

    static let opening = "Computing systems built over the last decade have systematically traded architectural transparency for centralized convenience. As engineers assemble layered abstractions upon proprietary orchestrators, the core operational surface grows opaque. To design infrastructure that survives institutional decay and network fragmentation, we must return to first principles: modular, unbundled primitives connected through deterministic contracts."

    static let unixStance = "The Unix philosophy was never merely about text streams and piping stdin to stdout; it was an epistemological stance toward complexity. When each component has a bounded domain, failures remain localized. State degradation in a single node does not precipitate catastrophic cascade events across the computational envelope."

    static let consensus = "Consider distributed state machines operating under asymmetric partition regimes. Rather than imposing monolithic quorum barriers that block execution during degraded connectivity, modern peer protocols prioritize eventual convergence through conflict-free replicated data types (CRDTs)."

    static let storage = "By decoupling storage engine semantics from network replication topologies, systems gain longevity. A database format that requires active cloud control planes will perish the day its maintainer pivots. An engine committed to open byte-level specifications endures for half a century."
}
