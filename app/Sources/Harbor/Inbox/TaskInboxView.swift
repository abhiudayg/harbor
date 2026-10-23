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
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(HarborColor.outlineVariant.opacity(0.3))
            HStack(spacing: 0) {
                taskList
                    .frame(width: 320)
                Divider().overlay(HarborColor.outlineVariant.opacity(0.3))
                detail
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .background(HarborColor.surface)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Task Inbox & Agent Pipeline")
                    .font(HarborTypography.editorial(size: 26, weight: .medium))
                    .foregroundStyle(HarborColor.onSurface)
                Spacer()
                Button("Done") { model.isInboxPresented = false }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
            }
            Text("\(model.pendingApprovals.count) approval required · \(groups.tasks(in: .running).count) running")
                .font(HarborTypography.mono(size: 11))
                .foregroundStyle(HarborColor.approvalText)
                .accessibilityIdentifier("inbox-approval-count")
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    private var taskList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(TaskInboxSection.allCases, id: \.self) { section in
                    let rows = groups.tasks(in: section)
                    if !rows.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
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
            .padding(14)
        }
        .scrollIndicators(.never)
        .background(HarborColor.surfaceLow)
    }

    private func taskRow(_ task: AgentTask) -> some View {
        let isSelected = task.id == selected?.id
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(task.steps.first?.displayName ?? "Task")
                    .font(HarborTypography.chrome(size: 13, weight: .medium))
                    .foregroundStyle(HarborColor.onSurface)
                    .lineLimit(1)
                Spacer()
                Text("STAGE \(min(task.cursor + 1, task.steps.count)) / \(task.steps.count)")
                    .font(HarborTypography.mono(size: 9, weight: .semibold))
                    .foregroundStyle(HarborColor.primary)
            }
            Text("\(task.site) · \(Self.stateLabel(task.state))")
                .font(HarborTypography.mono(size: 10))
                .foregroundStyle(HarborColor.onSurfaceVariant)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? HarborColor.surfaceLowest : .clear, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? HarborColor.outlineVariant.opacity(0.5) : .clear))
    }

    @ViewBuilder
    private var detail: some View {
        if let task = selected {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(task.steps.first?.displayName ?? "Task")
                        .font(HarborTypography.editorial(size: 22, weight: .medium))
                        .foregroundStyle(HarborColor.onSurface)
                    Text("Domain: \(task.site)")
                        .font(HarborTypography.mono(size: 12))
                        .foregroundStyle(HarborColor.onSurfaceVariant)
                    stageLine(task)
                    Text("State: \(Self.stateLabel(task.state))")
                        .font(HarborTypography.chrome(size: 12))
                        .foregroundStyle(HarborColor.onSurface)
                    if !task.state.isTerminal {
                        Button("Stop & abort") { Task { await model.stop(task) } }
                            .buttonStyle(.bordered)
                            .tint(HarborColor.approvalText)
                            .accessibilityIdentifier("inbox-stop")
                    }
                    if case .awaitingApproval = task.state, let request = pendingRequest(for: task) {
                        approvalCard(request)
                    }
                    scopeSection
                    outputSection(task)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.never)
        } else {
            Text("Select a task")
                .font(HarborTypography.chrome(size: 13))
                .foregroundStyle(HarborColor.onSurfaceVariant)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func stageLine(_ task: AgentTask) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("STAGE \(min(task.cursor + 1, task.steps.count)) / \(task.steps.count)")
                .font(HarborTypography.mono(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundStyle(HarborColor.primary)
            ProgressView(value: Double(task.cursor), total: Double(max(task.steps.count, 1)))
                .progressViewStyle(.linear)
                .tint(HarborColor.accentTeal)
            if case .awaitingApproval = task.state {
                Text("Paused at Step \(task.cursor + 1)")
                    .font(HarborTypography.chrome(size: 12, weight: .medium))
                    .foregroundStyle(HarborColor.approvalText)
            }
        }
    }

    private var scopeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("AUTHORIZED SITES")
                .font(HarborTypography.mono(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundStyle(HarborColor.onSurfaceVariant)
            Text(model.authorizedSites.isEmpty ? "None. Every action is denied or needs approval." : model.authorizedSites.joined(separator: ", "))
                .font(HarborTypography.chrome(size: 12))
                .foregroundStyle(HarborColor.onSurface)
            Text("PERMITTED ACTIONS")
                .font(HarborTypography.mono(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundStyle(HarborColor.onSurfaceVariant)
                .padding(.top, 4)
            Text(model.permittedActions.isEmpty ? "None granted. Sensitive actions ask first." : model.permittedActions.joined(separator: ", "))
                .font(HarborTypography.chrome(size: 12))
                .foregroundStyle(HarborColor.onSurface)
        }
    }

    private func approvalCard(_ request: ApprovalRequest) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AGENT ACTION APPROVAL")
                .font(HarborTypography.mono(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundStyle(HarborColor.approvalText)
            Text("\(Self.actionLabel(request.action)) on \(request.site)")
                .font(HarborTypography.editorial(size: 17, weight: .medium))
                .foregroundStyle(HarborColor.onSurface)
            Text("This step is held until you decide. Nothing runs before you approve it.")
                .font(HarborTypography.chrome(size: 12))
                .foregroundStyle(HarborColor.onSurfaceVariant)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Button("Deny") { Task { await model.deny(request) } }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("inbox-deny")
                    Button("Allow once") { Task { await model.approve(request, scope: .once) } }
                        .buttonStyle(.borderedProminent)
                        .tint(HarborColor.accentTeal)
                        .accessibilityIdentifier("inbox-allow-once")
                }
                HStack(spacing: 8) {
                    Button("Allow for this task") { Task { await model.approve(request, scope: .task) } }
                        .buttonStyle(.bordered)
                    Button("Allow for this site") { Task { await model.approve(request, scope: .site) } }
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HarborColor.approvalFill, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(HarborColor.approvalBorder))
    }

    @ViewBuilder
    private func outputSection(_ task: AgentTask) -> some View {
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
    }

    private func pendingRequest(for task: AgentTask) -> ApprovalRequest? {
        guard case .awaitingApproval(let id) = task.state else {
            return nil
        }
        return model.pendingApprovals.first { $0.id == id }
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
