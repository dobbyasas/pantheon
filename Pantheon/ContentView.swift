import AppKit
import SafariServices
import SwiftUI

private var blockerIdentifier: String {
    "\(Bundle.main.bundleIdentifier ?? "com.pantheon.adblock").blocker"
}

@MainActor
final class BlockerModel: ObservableObject {
    enum State: Equatable {
        case checking
        case enabled
        case disabled
        case unavailable(String)
    }

    @Published private(set) var state: State = .checking
    @Published private(set) var isReloading = false
    @Published var message: String?

    func refresh() {
        state = .checking
        SFContentBlockerManager.getStateOfContentBlocker(
            withIdentifier: blockerIdentifier
        ) { [weak self] blockerState, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.state = .unavailable(error.localizedDescription)
                } else {
                    self.state = blockerState?.isEnabled == true ? .enabled : .disabled
                }
            }
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
                    self.message = "Rules reloaded. Refresh any open Safari tabs."
                }
                self.refresh()
            }
        }
    }

    func openSafariSettings() {
        SFSafariApplication.showPreferencesForExtension(
            withIdentifier: blockerIdentifier
        ) { [weak self] error in
            guard let error else { return }
            DispatchQueue.main.async {
                self?.message = "Open Safari > Settings > Extensions and enable Pantheon Blocker. (\(error.localizedDescription))"
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
                Label("Blocks common ad-network requests", systemImage: "network.slash")
                Label("Stops popups on Pornhub", systemImage: "macwindow.badge.xmark")
                Label("Hides site-specific ad containers", systemImage: "rectangle.slash")
                Label("Cannot read your browsing history", systemImage: "hand.raised.fill")
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
        .frame(width: 540)
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
        case .disabled: "exclamationmark.triangle.fill"
        case .unavailable: "xmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch model.state {
        case .checking: .secondary
        case .enabled: .green
        case .disabled: .orange
        case .unavailable: .red
        }
    }

    private var statusTitle: String {
        switch model.state {
        case .checking: "Checking Safari…"
        case .enabled: "Protection is on"
        case .disabled: "Enable Pantheon Blocker in Safari"
        case .unavailable: "Extension not available"
        }
    }

    private var statusDetail: String {
        switch model.state {
        case .checking:
            "Reading the current extension status."
        case .enabled:
            "Safari is using Pantheon's compiled blocking rules."
        case .disabled:
            "Open Safari settings, select Extensions, and turn on Pantheon Blocker."
        case let .unavailable(error):
            "Build and run the containing app once, then enable the extension. \(error)"
        }
    }
}
