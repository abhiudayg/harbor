import HarborCore
import SwiftUI

struct CompanionPanelView: View {
    let model: AppModel
    @Environment(\.harborAccent) private var accent
    private let article = ReaderArticle.cognitiveErgonomics

    @State private var draft = ""
    @State private var messages: [ChatMessage] = []

    private var liveTasks: [AgentTask] {
        model.tasks.filter { !$0.state.isTerminal }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(HarborColor.outlineVariant.opacity(0.3))
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    approvalsSection
                    tasksSection
                    citationsSection
                    chatSection
                }
                .padding(16)
            }
            .scrollIndicators(.never)
            composer
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .glassPanel()
    }

    private var header: some View {
        HStack {
            MaterialIcon("auto_awesome", size: 12)
                .foregroundStyle(accent.ink)
            Text("Harbor Companion")
                .font(HarborTypography.text(size: 13, weight: .semibold))
                .foregroundStyle(HarborColor.onSurface)
            Spacer()
            Button {
                model.isAssistantPresented = false
            } label: {
                MaterialIcon("remove", size: 11)
                    .foregroundStyle(HarborColor.onSurfaceVariant)
            }
            .buttonStyle(.plain)
            .help("Hide Assistant")
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    private var approvalsSection: some View {
        section("Action required", badge: model.pendingApprovals.isEmpty ? nil : "\(model.pendingApprovals.count) pending") {
            if model.pendingApprovals.isEmpty {
                Text("Nothing is waiting for you.")
                    .font(HarborTypography.text(size: 12))
                    .foregroundStyle(HarborColor.onSurfaceVariant)
            }
            ForEach(model.pendingApprovals) { request in
                approvalCard(request)
            }
        }
    }

    private func approvalCard(_ request: ApprovalRequest) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(Self.actionLabel(request.action)) on \(request.site)")
                .font(HarborTypography.text(size: 12, weight: .semibold))
                .foregroundStyle(HarborColor.approvalText)
            Text("The agent is paused until you decide.")
                .font(HarborTypography.text(size: 11))
                .foregroundStyle(HarborColor.onSurfaceVariant)
            HStack(spacing: 8) {
                Button("Reject") { Task { await model.deny(request) } }
                    .buttonStyle(.bordered)
                Button("Approve once") { Task { await model.approve(request, scope: .once) } }
                    .buttonStyle(.borderedProminent)
                    .tint(accent.fill)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HarborColor.approvalFill, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(HarborColor.approvalBorder))
    }

    private var tasksSection: some View {
        section("Tasks (\(liveTasks.count))", badge: nil) {
            if liveTasks.isEmpty {
                Text("No agent tasks are running.")
                    .font(HarborTypography.text(size: 12))
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
                    .font(HarborTypography.text(size: 12, weight: .medium))
                    .foregroundStyle(HarborColor.onSurface)
                    .lineLimit(1)
                Spacer()
                Text("\(progressPercent(task))%")
                    .font(HarborTypography.text(size: 10))
                    .foregroundStyle(HarborColor.onSurfaceVariant)
            }
            ProgressView(value: progress(task))
                .progressViewStyle(.linear)
                .tint(accent.fill)
            HStack {
                Text(stepLine(task))
                    .font(HarborTypography.text(size: 11))
                    .foregroundStyle(HarborColor.onSurfaceVariant)
                Spacer()
                Button("Stop") {
                    Task { await model.stop(task) }
                }
                .buttonStyle(.plain)
                .font(HarborTypography.text(size: 11, weight: .medium))
                .foregroundStyle(HarborColor.approvalText)
                .accessibilityIdentifier("assistant-stop")
            }
        }
        .padding(10)
        .glassCard(cornerRadius: 8)
    }

    private var citationsSection: some View {
        section("Citations", badge: nil) {
            ForEach(article.footnotes, id: \.number) { note in
                Text("[\(note.number)] \(note.title)")
                    .font(HarborTypography.text(size: 10))
                    .foregroundStyle(accent.ink)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(accent.ink.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
            }
        }
    }

    private var chatSection: some View {
        section("Ask about this page", badge: "No model connected") {
            ForEach(messages) { message in
                Text(message.text)
                    .font(HarborTypography.text(size: 12))
                    .foregroundStyle(message.isUser ? HarborColor.onSurface : HarborColor.onSurfaceVariant)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        message.isUser ? HarborColor.surfaceLowest : HarborColor.surfaceContainer,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
            }
        }
    }

    private var composer: some View {
        HStack(spacing: 8) {
            TextField("Ask about this page", text: $draft)
                .textFieldStyle(.plain)
                .font(HarborTypography.text(size: 12))
                .onSubmit(send)
                .accessibilityIdentifier("assistant-composer")
            Button(action: send) {
                MaterialIcon("arrow_upward", size: 18)
                    .foregroundStyle(draft.trimmingCharacters(in: .whitespaces).isEmpty ? HarborColor.outline : accent.fill)
            }
            .buttonStyle(.plain)
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(12)
        .glassPanel()
        .overlay(alignment: .top) {
            Divider().overlay(HarborColor.outlineVariant.opacity(0.3))
        }
    }

    private func send() {
        let question = draft.trimmingCharacters(in: .whitespaces)
        guard !question.isEmpty else {
            return
        }
        draft = ""
        messages.append(ChatMessage(isUser: true, text: question))
        messages.append(ChatMessage(
            isUser: false,
            text: "No language model is connected to Harbor yet, so this question was not answered."
        ))
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

    private static func actionLabel(_ action: ActionClass) -> String {
        switch action {
        case .read: "Read page"
        case .navigate: "Navigate"
        case .click: "Click"
        case .typeText: "Type"
        case .submitForm: "Submit form"
        case .sendMessage: "Send message"
        case .purchase: "Purchase"
        case .deleteData: "Delete data"
        case .download: "Download"
        case .fillCredential: "Fill credential"
        case .createTask: "Create task"
        }
    }

    private func section<Content: View>(_ title: String, badge: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title.uppercased())
                    .font(HarborTypography.text(size: 10, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(HarborColor.onSurfaceVariant)
                Spacer()
                if let badge {
                    Text(badge)
                        .font(HarborTypography.text(size: 9, weight: .medium))
                        .foregroundStyle(accent.ink)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(accent.ink.opacity(0.10), in: RoundedRectangle(cornerRadius: 4))
                }
            }
            content()
        }
    }
}

private struct ChatMessage: Identifiable {
    let id = UUID()
    let isUser: Bool
    let text: String
}
