import AppKit
import HarborCore
import SwiftUI

struct ClientsSheetView: View {
    let model: AppModel
    @State private var name = ""
    @State private var issuedToken: String?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider().overlay(HarborColor.outlineVariant.opacity(0.3))
            issueSection
            clientList
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: 620, height: 520)
        .background(HarborColor.paper)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("MCP clients")
                    .font(HarborTypography.headline(size: 20, weight: .medium))
                    .foregroundStyle(HarborColor.onSurface)
                Text(serverLine)
                    .font(HarborTypography.text(size: 11))
                    .foregroundStyle(HarborColor.onSurfaceVariant)
                    .accessibilityIdentifier("clients-server-status")
            }
            Spacer()
            Button("Done") { model.isClientsPresented = false }
                .keyboardShortcut(.cancelAction)
        }
    }

    private var serverLine: String {
        guard let port = model.serverPort else {
            return "Server not running"
        }
        return "Listening on 127.0.0.1:\(port) · loopback only"
    }

    private var issueSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("NEW CLIENT")
                .font(HarborTypography.text(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundStyle(HarborColor.onSurfaceVariant)
            HStack {
                TextField("Client name, for example Research agent", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("client-name-field")
                Button("Create client") {
                    Task { await create() }
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if let issuedToken {
                tokenBox(issuedToken)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(HarborTypography.text(size: 12))
                    .foregroundStyle(HarborColor.approvalText)
            }
            Text("New clients have no grants. Nothing they send runs until you grant it.")
                .font(HarborTypography.text(size: 11))
                .foregroundStyle(HarborColor.onSurfaceVariant)
        }
    }

    private func tokenBox(_ token: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Copy this token now. Harbor keeps only a digest and cannot show it again.")
                .font(HarborTypography.text(size: 11, weight: .medium))
                .foregroundStyle(HarborColor.approvalText)
            HStack {
                Text(token)
                    .font(HarborTypography.text(size: 11))
                    .foregroundStyle(HarborColor.onSurface)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .accessibilityIdentifier("issued-token")
                Spacer()
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(token, forType: .string)
                }
            }
        }
        .padding(10)
        .background(HarborColor.approvalFill, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(HarborColor.approvalBorder))
    }

    private var clientList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CONNECTED CLIENTS (\(model.clients.count))")
                .font(HarborTypography.text(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundStyle(HarborColor.onSurfaceVariant)
            if model.clients.isEmpty {
                Text("No clients yet.")
                    .font(HarborTypography.text(size: 12))
                    .foregroundStyle(HarborColor.onSurfaceVariant)
            }
            ForEach(model.clients) { client in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(client.name)
                            .font(HarborTypography.text(size: 13, weight: .medium))
                            .foregroundStyle(HarborColor.onSurface)
                        Text("\(client.grantCount) grants")
                            .font(HarborTypography.text(size: 10))
                            .foregroundStyle(HarborColor.onSurfaceVariant)
                    }
                    Spacer()
                    Button("Revoke") {
                        Task { await revoke(client.id) }
                    }
                    .accessibilityIdentifier("revoke-\(client.name)")
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func create() async {
        errorMessage = nil
        do {
            issuedToken = try await model.issueClient(name: name)
            name = ""
        } catch {
            errorMessage = "Could not create the client. Use a name of 1 to 64 characters."
        }
    }

    private func revoke(_ id: String) async {
        errorMessage = nil
        do {
            try await model.revokeClient(id: id)
        } catch {
            errorMessage = "Could not revoke that client. It may already be gone."
        }
    }
}
