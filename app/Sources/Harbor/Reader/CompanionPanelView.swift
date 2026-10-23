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

    private var scopeName: String {
        model.tabs.first { $0.id == model.activeTabID }
            .flatMap { model.spaceNames[$0.spaceID] } ?? "This page"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            scopeBar
            Divider().overlay(HarborColor.outlineVariant.opacity(0.4))
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    tasksSection
                    approvalsSection
                    chatSection
                }
                .padding(16)
            }
            .scrollIndicators(.never)
            composer
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.white.opacity(0.72))
    }

    private var header: some View {
        HStack(spacing: 10) {
            MaterialIcon("auto_awesome", size: 16)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(accent.ink, in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("Harbor Companion")
                        .font(HarborTypography.headline(size: 14, weight: .semibold))
                        .foregroundStyle(HarborColor.onSurface)
                    Circle()
                        .fill(HarborColor.accentTeal)
                        .frame(width: 6, height: 6)
                }
                Text("Contextual Intelligence Engine")
                    .font(HarborTypography.text(size: 11))
                    .foregroundStyle(HarborColor.onSurfaceVariant)
            }
            Spacer()
            Button {
                model.isAssistantPresented = false
            } label: {
                MaterialIcon("view_sidebar", size: 16)
                    .foregroundStyle(HarborColor.onSurfaceVariant)
            }
            .buttonStyle(.plain)
            .help("Hide Assistant")
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var scopeBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(accent.fill)
                        .frame(width: 6, height: 6)
                    MaterialIcon("folder", size: 12)
                    Text(scopeName)
                        .font(HarborTypography.text(size: 11, weight: .medium))
                }
                .foregroundStyle(HarborColor.onSurface)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(HarborColor.surfaceLowest, in: Capsule())
                .overlay(Capsule().stroke(HarborColor.outlineVariant))
                ForEach(article.footnotes, id: \.number) { note in
                    Text("[\(note.number)] \(note.title)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(HarborColor.onSurfaceVariant)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(HarborColor.surfaceLowest, in: Capsule())
                        .overlay(Capsule().stroke(HarborColor.outlineVariant))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    private var tasksSection: some View {
        section("Tasks in progress (\(liveTasks.count))", badge: nil) {
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                MaterialIcon("data_object", size: 14)
                    .foregroundStyle(accent.ink)
                Text(task.steps.first?.displayName ?? "Task")
                    .font(HarborTypography.text(size: 12, weight: .medium))
                    .foregroundStyle(HarborColor.onSurface)
                    .lineLimit(1)
                Spacer()
                Text("\(progressPercent(task))%")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(HarborColor.onSurfaceVariant)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(HarborColor.surfaceContainer, in: RoundedRectangle(cornerRadius: 4))
            }
            ProgressView(value: progress(task))
                .progressViewStyle(.linear)
                .tint(accent.fill)
            HStack {
                Text(stepLine(task))
                    .font(HarborTypography.text(size: 11))
                    .foregroundStyle(HarborColor.onSurfaceVariant)
                Spacer()
                Button {
                    Task { await model.stop(task) }
                } label: {
                    MaterialIcon("stop", size: 14)
                        .foregroundStyle(HarborColor.approvalText)
                }
                .buttonStyle(.plain)
                .help("Stop task")
                .accessibilityIdentifier("assistant-stop")
            }
        }
        .padding(12)
        .background(HarborColor.surfaceLowest, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(HarborColor.outlineVariant.opacity(0.6)))
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
            HStack {
                Text("ACTION REQUIRED")
                    .font(HarborTypography.text(size: 9, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(HarborColor.approvalText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(HarborColor.amberBadgeFill, in: RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(HarborColor.amberBadgeBorder))
                Spacer()
                HStack(spacing: 4) {
                    MaterialIcon("language", size: 12)
                    Text(request.site)
                        .font(HarborTypography.text(size: 10, weight: .medium))
                }
                .foregroundStyle(HarborColor.approvalText)
            }
            Text("\(Self.actionLabel(request.action)) on \(request.site)")
                .font(HarborTypography.text(size: 13, weight: .semibold))
                .foregroundStyle(HarborColor.onSurface)
            Text("The agent is paused until you decide.")
                .font(HarborTypography.text(size: 11))
                .foregroundStyle(HarborColor.onSurfaceVariant)
            HStack(spacing: 8) {
                Button {
                    Task { await model.approve(request, scope: .once) }
                } label: {
                    HStack(spacing: 6) {
                        MaterialIcon("check", size: 14)
                        Text("Approve")
                            .font(HarborTypography.text(size: 12, weight: .medium))
                        MaterialIcon("keyboard_return", size: 13)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .background(accent.fill, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                Button {
                    Task { await model.deny(request) }
                } label: {
                    Text("Reject")
                        .font(HarborTypography.text(size: 12, weight: .medium))
                        .foregroundStyle(HarborColor.onSurface)
                        .padding(.horizontal, 14)
                        .frame(height: 30)
                        .background(HarborColor.surfaceLowest, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(HarborColor.outlineVariant))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HarborColor.approvalFill, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(HarborColor.approvalBorder))
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
        .background(HarborColor.surfaceLowest)
        .overlay(alignment: .top) {
            Divider().overlay(HarborColor.outlineVariant.opacity(0.4))
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
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
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
