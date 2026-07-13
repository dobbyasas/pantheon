import AppKit
import SafariServices
import SwiftUI

private var blockerIdentifier: String {
    "\(Bundle.main.bundleIdentifier ?? "com.pantheon.adblock").blocker"
}

private var pageCleanerIdentifier: String {
    "\(Bundle.main.bundleIdentifier ?? "com.pantheon.adblock").page-cleaner"
}

@MainActor
final class BlockerModel: ObservableObject {
    enum State: Equatable {
        case checking
        case enabled
        case partial
        case disabled
        case unavailable(String)
    }

    @Published private(set) var state: State = .checking
    @Published private(set) var contentBlockerEnabled = false
    @Published private(set) var pageCleanerEnabled = false
    @Published private(set) var isReloading = false
    @Published var message: String?

    private var contentBlockerChecked = false
    private var pageCleanerChecked = false
    private var statusErrors: [String] = []

    func refresh() {
        state = .checking
        contentBlockerChecked = false
        pageCleanerChecked = false
        contentBlockerEnabled = false
        pageCleanerEnabled = false
        statusErrors = []

        SFContentBlockerManager.getStateOfContentBlocker(
            withIdentifier: blockerIdentifier
        ) { [weak self] blockerState, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.contentBlockerChecked = true
                self.contentBlockerEnabled = blockerState?.isEnabled == true
                if let error {
                    self.statusErrors.append("Network blocker: \(error.localizedDescription)")
                }
                self.finishRefreshIfReady()
            }
        }

        SFSafariExtensionManager.getStateOfSafariExtension(
            withIdentifier: pageCleanerIdentifier
        ) { [weak self] cleanerState, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.pageCleanerChecked = true
                self.pageCleanerEnabled = cleanerState?.isEnabled == true
                if let error {
                    self.statusErrors.append("Page cleaner: \(error.localizedDescription)")
                }
                self.finishRefreshIfReady()
            }
        }
    }

    private func finishRefreshIfReady() {
        guard contentBlockerChecked, pageCleanerChecked else { return }
        if contentBlockerEnabled && pageCleanerEnabled {
            state = .enabled
        } else if contentBlockerEnabled || pageCleanerEnabled {
            state = .partial
        } else if !statusErrors.isEmpty {
            state = .unavailable(statusErrors.joined(separator: " "))
        } else {
            state = .disabled
        }
    }

    func reloadRules() {
        guard !isReloading else { return }
        isReloading = true
        message = nil

        SFContentBlockerManager.reloadContentBlocker(
            withIdentifier: blockerIdentifier
        ) { [weak self] error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isReloading = false
                if let error {
                    self.message = "Safari could not reload the rules: \(error.localizedDescription)"
                } else {
                    self.message = "Rules reloaded. Close and reopen the Pornhub tab."
                }
                self.refresh()
            }
        }
    }

    func openSafariSettings() {
        SFSafariApplication.showPreferencesForExtension(
            withIdentifier: pageCleanerIdentifier
        ) { [weak self] error in
            guard let error else { return }
            DispatchQueue.main.async {
                self?.message = "Open Safari > Settings > Extensions, enable both Pantheon extensions, and allow Pantheon Page Cleaner on pornhub.com. (\(error.localizedDescription))"
                NSWorkspace.shared.openApplication(
                    at: URL(fileURLWithPath: "/Applications/Safari.app"),
                    configuration: NSWorkspace.OpenConfiguration()
                )
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var model = BlockerModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 16) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Pantheon")
                        .font(.largeTitle.bold())
                    Text("Fast, native ad blocking for Safari")
                        .foregroundStyle(.secondary)
                }
            }

            statusCard

            VStack(alignment: .leading, spacing: 12) {
                Label(
                    "Network blocker: \(model.contentBlockerEnabled ? "On" : "Off")",
                    systemImage: model.contentBlockerEnabled ? "checkmark.circle.fill" : "circle"
                )
                Label(
                    "Pornhub page cleaner: \(model.pageCleanerEnabled ? "On" : "Off")",
                    systemImage: model.pageCleanerEnabled ? "checkmark.circle.fill" : "circle"
                )
                Divider()
                Label("Blocks common ad-network requests", systemImage: "network.slash")
                Label("Removes dynamic Pornhub banners and popups", systemImage: "rectangle.slash")
                Label("Clears Pornhub player ad-roll configuration", systemImage: "play.slash")
                Label("Page access is limited to pornhub.com", systemImage: "hand.raised.fill")
            }
            .font(.body)

            if let message = model.message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button("Open Safari Extension Settings") {
                    model.openSafariSettings()
                }
                .buttonStyle(.borderedProminent)

                Button(model.isReloading ? "Reloading…" : "Reload Rules") {
                    model.reloadRules()
                }
                .disabled(model.isReloading)

                Spacer()

                Button {
                    model.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Check extension status")
            }
        }
        .padding(28)
        .frame(width: 600)
        .task {
            model.refresh()
        }
    }

    @ViewBuilder
    private var statusCard: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .font(.title2)

            VStack(alignment: .leading, spacing: 3) {
                Text(statusTitle)
                    .font(.headline)
                Text(statusDetail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(16)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
    }

    private var statusIcon: String {
        switch model.state {
        case .checking: "hourglass"
        case .enabled: "checkmark.circle.fill"
        case .partial: "exclamationmark.triangle.fill"
        case .disabled: "exclamationmark.triangle.fill"
        case .unavailable: "xmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch model.state {
        case .checking: .secondary
        case .enabled: .green
        case .partial: .orange
        case .disabled: .orange
        case .unavailable: .red
        }
    }

    private var statusTitle: String {
        switch model.state {
        case .checking: "Checking Safari…"
        case .enabled: "Both protection layers are on"
        case .partial: "One protection layer is off"
        case .disabled: "Enable both Pantheon extensions"
        case .unavailable: "Extension not available"
        }
    }

    private var statusDetail: String {
        switch model.state {
        case .checking:
            "Reading the current extension status."
        case .enabled:
            "Allow Pantheon Page Cleaner on pornhub.com, then close and reopen the tab."
        case .partial:
            "Open Safari extension settings and turn on both Pantheon Blocker and Pantheon Page Cleaner."
        case .disabled:
            "Open Safari settings, select Extensions, and turn on both Pantheon extensions."
        case let .unavailable(error):
            "Build and run the containing app once, then enable the extension. \(error)"
        }
    }
}
