import HarborCore
import SwiftUI

struct TaskInboxView: View {
    let model: AppModel
    @State private var selection: UUID?

    private var groups: TaskInboxGroups {
        TaskInboxGroups.make(tasks: model.tasks)
    }

    private var selected: AgentTask? {
        model.tasks.first { $0.id == selection } ?? model.tasks.first
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Task Inbox & Agent Approval")
                    .font(HarborTypography.editorial(size: 20, weight: .medium))
                    .foregroundStyle(HarborColor.onSurface)
                Spacer()
                Text("\(model.pendingApprovals.count) approval required")
                    .font(HarborTypography.mono(size: 11))
                    .foregroundStyle(HarborColor.approvalText)
                    .accessibilityIdentifier("inbox-approval-count")
                Button("Done") { model.isInboxPresented = false }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .frame(height: 52)
            Divider().overlay(HarborColor.outlineVariant.opacity(0.3))
            HStack(spacing: 0) {
                taskList
                    .frame(width: 320)
                Divider().overlay(HarborColor.outlineVariant.opacity(0.3))
                detail
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .frame(width: 900, height: 560)
        .background(HarborColor.paper)
    }

    private var taskList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(TaskInboxSection.allCases, id: \.self) { section in
                    let rows = groups.tasks(in: section)
                    if !rows.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(section.rawValue) (\(rows.count))".uppercased())
                                .font(HarborTypography.mono(size: 10, weight: .semibold))
                                .tracking(1)
                                .foregroundStyle(HarborColor.onSurfaceVariant)
                                .padding(.horizontal, 8)
                            ForEach(rows) { task in
                                Button {
                                    selection = task.id
                                } label: {
                                    taskRow(task)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                if model.tasks.isEmpty {
                    Text("No tasks yet. Tasks appear here when an agent runs or asks for approval.")
                        .font(HarborTypography.chrome(size: 12))
                        .foregroundStyle(HarborColor.onSurfaceVariant)
                        .padding(8)
                }
            }
            .padding(12)
        }
        .scrollIndicators(.never)
        .background(HarborColor.surfaceLow)
    }

    private func taskRow(_ task: AgentTask) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(task.steps.first.map(Self.label) ?? "Task")
                .font(HarborTypography.chrome(size: 13, weight: .medium))
                .foregroundStyle(HarborColor.onSurface)
                .lineLimit(1)
            Text("\(task.site) · \(Self.stateLabel(task.state))")
                .font(HarborTypography.mono(size: 10))
                .foregroundStyle(HarborColor.onSurfaceVariant)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(task.id == selected?.id ? HarborColor.surfaceLowest : .clear, in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var detail: some View {
        if let task = selected {
            VStack(alignment: .leading, spacing: 14) {
                Text(task.steps.first.map(Self.label) ?? "Task")
                    .font(HarborTypography.editorial(size: 22, weight: .medium))
                    .foregroundStyle(HarborColor.onSurface)
                Text("Site: \(task.site)")
                    .font(HarborTypography.mono(size: 12))
                    .foregroundStyle(HarborColor.onSurfaceVariant)
                Text("State: \(Self.stateLabel(task.state))")
                    .font(HarborTypography.chrome(size: 12))
                    .foregroundStyle(HarborColor.onSurface)
                if case .awaitingApproval = task.state, let request = pendingRequest(for: task) {
                    approvalCard(request)
                }
                if !task.outputs.isEmpty {
                    Text("OUTPUT (UNTRUSTED PAGE DATA)")
                        .font(HarborTypography.mono(size: 10, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(HarborColor.onSurfaceVariant)
                    ForEach(Array(task.outputs.enumerated()), id: \.offset) { _, output in
                        Text(output.value)
                            .font(HarborTypography.chrome(size: 12))
                            .foregroundStyle(HarborColor.onSurface)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(HarborColor.surfaceLowest, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                Spacer()
            }
            .padding(20)
        } else {
            Text("Select a task")
                .font(HarborTypography.chrome(size: 13))
                .foregroundStyle(HarborColor.onSurfaceVariant)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func approvalCard(_ request: ApprovalRequest) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(Self.actionLabel(request.action)) on \(request.site)")
                .font(HarborTypography.chrome(size: 13, weight: .semibold))
                .foregroundStyle(HarborColor.approvalText)
            Text("This step is held until you decide. Nothing runs before you approve it.")
                .font(HarborTypography.chrome(size: 12))
                .foregroundStyle(HarborColor.onSurfaceVariant)
            HStack {
                Button("Deny") { Task { await model.deny(request) } }
                    .accessibilityIdentifier("inbox-deny")
                Button("Allow once") { Task { await model.approve(request, scope: .once) } }
                    .accessibilityIdentifier("inbox-allow-once")
                Button("Allow for this site") { Task { await model.approve(request, scope: .site) } }
            }
            .buttonStyle(.bordered)
        }
        .padding(14)
        .background(HarborColor.approvalFill, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(HarborColor.approvalBorder))
    }

    private func pendingRequest(for task: AgentTask) -> ApprovalRequest? {
        guard case .awaitingApproval(let id) = task.state else {
            return nil
        }
        return model.pendingApprovals.first { $0.id == id }
    }

    private static func label(_ step: AgentStep) -> String {
        switch step {
        case .navigate(let url): "Open \(url.host ?? url.absoluteString)"
        case .readPage: "Read page"
        case .click: "Click element"
        case .typeText: "Type into field"
        case .submitForm: "Submit form"
        case .sendMessage: "Send message"
        case .download: "Download file"
        case .fillCredential: "Fill credential"
        }
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

    private static func stateLabel(_ state: AgentTaskState) -> String {
        switch state {
        case .running: "Running"
        case .awaitingApproval: "Waiting for approval"
        case .completed: "Completed"
        case .failed(let reason): "Failed: \(reason)"
        case .stopped: "Stopped"
        }
    }
}
