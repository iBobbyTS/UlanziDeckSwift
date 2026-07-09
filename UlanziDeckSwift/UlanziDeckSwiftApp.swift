//
//  UlanziDeckSwiftApp.swift
//  UlanziDeckSwift
//
//  Created by iBobby on 2026-06-13.
//

import SwiftUI
import AppKit
import Combine

@main
struct UlanziDeckSwiftApp: App {
    private static let mainWindowID = "main-window"
    private let singleInstanceAcquired: Bool
    private let duplicateApplicationAlert: DuplicateApplicationAlert?
    @StateObject private var appState: UlanziDeckAppState

    init() {
        if Self.isRunningTests {
            singleInstanceAcquired = true
            duplicateApplicationAlert = nil
            _appState = StateObject(wrappedValue: UlanziDeckAppState())
            return
        }

        switch SingleInstanceGuard().acquire() {
        case .acquired:
            singleInstanceAcquired = true
            duplicateApplicationAlert = nil
            _appState = StateObject(wrappedValue: UlanziDeckAppState())
        case let .blockedByExistingApplication(existingApplication):
            singleInstanceAcquired = false
            duplicateApplicationAlert = DuplicateApplicationAlert(existingApplication: existingApplication)
            _appState = StateObject(wrappedValue: UlanziDeckAppState(isEnabled: false))
        case .blockedByUnknownApplication:
            singleInstanceAcquired = false
            duplicateApplicationAlert = DuplicateApplicationAlert(existingApplication: nil)
            _appState = StateObject(wrappedValue: UlanziDeckAppState(isEnabled: false))
        }
    }

    var body: some Scene {
        WindowGroup("Ulanzi Deck", id: Self.mainWindowID) {
            if singleInstanceAcquired {
                if let connectionModel = appState.connectionModel {
                    RootView(connectionModel: connectionModel)
                } else {
                    EmptyView()
                }
            } else if let duplicateApplicationAlert {
                DuplicateApplicationAlertPresenter(alert: duplicateApplicationAlert)
                    .frame(width: 0, height: 0)
            } else {
                EmptyView()
            }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            if !singleInstanceAcquired {
                CommandGroup(replacing: .newItem) {}
            }
        }

        MenuBarExtra("Ulanzi Deck", systemImage: "rectangle.connected.to.line.below") {
            MenuBarContent(mainWindowID: Self.mainWindowID)
        }
    }

    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}

@MainActor
final class UlanziDeckAppState: ObservableObject {
    @Published private(set) var connectionModel: H200ConnectionModel?

    private let brightnessRuntime: BrightnessAdjustmentRegistering

    init(
        isEnabled: Bool = true,
        brightnessRuntime: BrightnessAdjustmentRegistering? = nil,
        connectionModelFactory: (@MainActor () -> H200ConnectionModel)? = nil
    ) {
        self.brightnessRuntime = brightnessRuntime ?? BrightnessAdjustmentRuntime.shared
        guard isEnabled else {
            return
        }

        let connectionModel = connectionModelFactory?() ?? H200ConnectionModel()
        self.connectionModel = connectionModel
        self.brightnessRuntime.register(connectionModel)
        connectionModel.checkOnLaunch()
    }

    isolated deinit {
        guard let connectionModel else {
            return
        }

        brightnessRuntime.unregister(connectionModel)
    }
}

private struct MenuBarContent: View {
    @Environment(\.openWindow) private var openWindow
    let mainWindowID: String

    var body: some View {
        Button("打开主窗口") {
            openMainWindow()
        }

        Divider()

        Button("退出 Ulanzi Deck") {
            NSApplication.shared.terminate(nil)
        }
    }

    private func openMainWindow() {
        openWindow(id: mainWindowID)
        NSApplication.shared.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            NSApplication.shared.windows
                .first { $0.identifier?.rawValue == mainWindowID || $0.title == "Ulanzi Deck" }?
                .makeKeyAndOrderFront(nil)
        }
    }
}

struct DuplicateApplicationAlertPresenter: NSViewRepresentable {
    let alert: DuplicateApplicationAlert

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.present(alert, from: view)
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.present(alert, from: nsView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        private var didPresent = false
        private var windowLookupRetryCount = 0

        func present(_ alert: DuplicateApplicationAlert, from view: NSView) {
            guard !didPresent else {
                return
            }

            guard let window = view.window else {
                windowLookupRetryCount += 1
                if windowLookupRetryCount < 4 {
                    DispatchQueue.main.async {
                        self.present(alert, from: view)
                    }
                    return
                }

                didPresent = true
                showAlert(alert)
                return
            }

            didPresent = true
            window.orderOut(nil)
            window.close()
            showAlert(alert)
        }

        private func showAlert(_ alert: DuplicateApplicationAlert) {
            let panel = NSAlert()
            panel.alertStyle = .warning
            panel.messageText = alert.title
            panel.informativeText = alert.message
            panel.addButton(withTitle: "退出")
            NSApplication.shared.activate()
            panel.runModal()
            NSApplication.shared.terminate(nil)
        }
    }
}

struct DuplicateApplicationAlert: Equatable {
    let title = "另一个 Ulanzi Deck 正在运行"
    let message: String

    init(existingApplication: ExistingApplication?) {
        var lines = ["检测到已有 Ulanzi Deck 进程正在运行。请先退出已有进程后再重新打开。"]

        if let processIdentifier = existingApplication?.processIdentifier {
            lines.append("PID：\(processIdentifier)")
        }

        if let path = existingApplication?.bundleURL?.path {
            lines.append("路径：\(path)")
        }

        message = lines.joined(separator: "\n")
    }
}
