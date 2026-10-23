import SwiftUI

struct CompanionPanelView: View {
    private static let arguments = [
        "De-abstraction of layers: Modern clouds enforce proprietary boundaries that prevent root-cause diagnostics.",
        "Unix composability as insurance: Bounded input/output contracts ensure isolated failure blast radiuses.",
        "Local-first convergence: CRDTs provide resilience during network collapse without centralized orchestrators.",
    ]

    private static let references = [
        ("A Philosophy of Software Design", "stanford.edu"),
        ("Local-first Software: You Own Your Data", "inkandswitch.com"),
        ("CAP Twelve Years Later: How the Rules Have Changed", "ieee.org"),
    ]

    private static let automations = [
        ("Save to Obsidian vault", "COMPLETED"),
        ("Extract BibTeX citation", "RUN"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(HarborColor.outlineVariant.opacity(0.3))
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    section("Key arguments", badge: "AI Synthesized") {
                        ForEach(Self.arguments, id: \.self) { argument in
                            Text(argument)
                                .font(HarborTypography.chrome(size: 12))
                                .foregroundStyle(HarborColor.onSurfaceVariant)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    section("Extracted references (3)", badge: nil) {
                        ForEach(Self.references, id: \.0) { reference in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(reference.0)
                                    .font(HarborTypography.chrome(size: 12, weight: .medium))
                                    .foregroundStyle(HarborColor.onSurface)
                                Text(reference.1)
                                    .font(HarborTypography.mono(size: 10))
                                    .foregroundStyle(HarborColor.outline)
                            }
                        }
                    }
                    section("Automations & sinks", badge: nil) {
                        ForEach(Self.automations, id: \.0) { automation in
                            HStack {
                                Text(automation.0)
                                    .font(HarborTypography.chrome(size: 12))
                                    .foregroundStyle(HarborColor.onSurface)
                                Spacer()
                                Text(automation.1)
                                    .font(HarborTypography.mono(size: 9, weight: .semibold))
                                    .foregroundStyle(HarborColor.primary)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .scrollIndicators(.never)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(HarborColor.surfaceLow)
    }

    private var header: some View {
        HStack {
            Text("Harbor Companion")
                .font(HarborTypography.chrome(size: 13, weight: .semibold))
                .foregroundStyle(HarborColor.onSurface)
            Spacer()
            Image(systemName: "minus")
                .font(.system(size: 11))
                .foregroundStyle(HarborColor.onSurfaceVariant)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    private func section<Content: View>(_ title: String, badge: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title.uppercased())
                    .font(HarborTypography.mono(size: 10, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(HarborColor.onSurfaceVariant)
                Spacer()
                if let badge {
                    Text(badge)
                        .font(HarborTypography.mono(size: 9, weight: .medium))
                        .foregroundStyle(HarborColor.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(HarborColor.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 4))
                }
            }
            content()
        }
    }
}
