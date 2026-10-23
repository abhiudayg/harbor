import HarborCore
import SwiftUI

struct CompanionPanelView: View {
    let model: AppModel

    private static let arguments = [
        "De-abstraction of layers: Modern clouds enforce proprietary boundaries that prevent root-cause diagnostics.",
        "Unix composability as insurance: Bounded input/output contracts ensure isolated failure blast radiuses.",
        "Local-first convergence: CRDTs provide resilience during network collapse without centralized orchestrators.",
    ]

    private static let citations = ["RFC-8910", "Klim Spec", "A Philosophy of Software Design"]

    private var liveTasks: [AgentTask] {
        model.tasks.filter { !$0.state.isTerminal }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(HarborColor.outlineVariant.opacity(0.3))
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    tasksSection
                    citationsSection
                    outlineSection
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
            Image(systemName: "sparkles")
                .font(.system(size: 12))
                .foregroundStyle(HarborColor.primary)
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

    private var tasksSection: some View {
        section("Tasks (\(liveTasks.count))", badge: liveTasks.isEmpty ? nil : "\(liveTasks.count) live") {
            if liveTasks.isEmpty {
                Text("No agent tasks are running.")
                    .font(HarborTypography.chrome(size: 12))
                    .foregroundStyle(HarborColor.onSurfaceVariant)
            }
            ForEach(liveTasks) { task in
                taskRow(task)
            }
        }
    }

    private func taskRow(_ task: AgentTask) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(task.steps.first?.displayName ?? "Task")
                    .font(HarborTypography.chrome(size: 12, weight: .medium))
                    .foregroundStyle(HarborColor.onSurface)
                    .lineLimit(1)
                Spacer()
                Text("\(progressPercent(task))%")
                    .font(HarborTypography.mono(size: 10))
                    .foregroundStyle(HarborColor.onSurfaceVariant)
            }
            ProgressView(value: progress(task))
                .progressViewStyle(.linear)
                .tint(HarborColor.accentTeal)
            HStack {
                Text(stepLine(task))
                    .font(HarborTypography.chrome(size: 11))
                    .foregroundStyle(HarborColor.onSurfaceVariant)
                Spacer()
                Button("Stop") {
                    Task { await model.stop(task) }
                }
                .buttonStyle(.plain)
                .font(HarborTypography.chrome(size: 11, weight: .medium))
                .foregroundStyle(HarborColor.approvalText)
                .accessibilityIdentifier("assistant-stop")
            }
        }
        .padding(10)
        .background(HarborColor.surfaceLowest, in: RoundedRectangle(cornerRadius: 8))
    }

    private func progress(_ task: AgentTask) -> Double {
        guard !task.steps.isEmpty else {
            return 0
        }
        return Double(task.cursor) / Double(task.steps.count)
    }

    private func progressPercent(_ task: AgentTask) -> Int {
        Int((progress(task) * 100).rounded())
    }

    private func stepLine(_ task: AgentTask) -> String {
        if case .awaitingApproval = task.state {
            return "Waiting for approval"
        }
        return "Step \(min(task.cursor + 1, task.steps.count)) of \(task.steps.count)"
    }

    private var citationsSection: some View {
        section("Citations", badge: nil) {
            HStack(spacing: 6) {
                ForEach(Array(Self.citations.enumerated()), id: \.offset) { index, citation in
                    Text("[\(index + 1)] \(citation)")
                        .font(HarborTypography.mono(size: 10))
                        .foregroundStyle(HarborColor.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(HarborColor.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                }
            }
        }
    }

    private var outlineSection: some View {
        section("Key arguments", badge: "AI Synthesized") {
            ForEach(Self.arguments, id: \.self) { argument in
                Text(argument)
                    .font(HarborTypography.chrome(size: 12))
                    .foregroundStyle(HarborColor.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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
