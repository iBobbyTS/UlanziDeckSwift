import SwiftUI

struct RootView: View {
    private let windowContentMinimumSize = CGSize(width: 880, height: 640)
    private let windowContentMaximumSize = CGSize(width: 1000, height: CGFloat.greatestFiniteMagnitude)
    @StateObject private var connectionModel: H200ConnectionModel

    init(
        discovery: H200Discovering = H200HIDDiscovery(),
        syncer: H200DeckSyncing = H200HIDDeckSyncer(),
        configurationStore: DeckConfigurationStoring = UserDefaultsDeckConfigurationStore(),
        folderOpener: FinderFolderOpening? = nil,
        smbServerConnector: SMBServerConnecting? = nil,
        sub2APIFetcher: Sub2APIFetching = Sub2APIFetcher()
    ) {
        _connectionModel = StateObject(wrappedValue: H200ConnectionModel(
            discovery: discovery,
            syncer: syncer,
            configurationStore: configurationStore,
            folderOpener: folderOpener,
            smbServerConnector: smbServerConnector,
            sub2APIFetcher: sub2APIFetcher
        ))
    }

    var body: some View {
        ContentView(
            connectedDevice: connectionModel.connectedDevice,
            brightnessPercent: connectionModel.brightnessPercent,
            interactionState: connectionModel.interactionState,
            onKeySelection: { keyID in
                connectionModel.selectKey(keyID: keyID)
            },
            onKeyFunctionDeletion: { keyID in
                connectionModel.clearKeyFunction(keyID: keyID)
            },
            onFunctionSelection: { function in
                connectionModel.assignSelectedFunction(function)
            },
            onTallyDefaultValueChange: { value in
                connectionModel.setSelectedTallyDefaultValue(value)
            },
            onFolderPathSelection: { path in
                connectionModel.setSelectedFolderPath(path)
            },
            onSMBServerAddressChange: { address in
                connectionModel.setSelectedSMBServerAddress(address)
            },
            onBrightnessPercentPreview: { percent in
                connectionModel.previewBrightnessPercent(percent)
            },
            onBrightnessPercentCommit: { percent in
                connectionModel.commitBrightnessPercent(percent)
            },
            onSub2APIBaseURLChange: { baseURL in
                connectionModel.setSelectedSub2APIBaseURL(baseURL)
            },
            onSub2APITargetGroupIDChange: { groupID in
                connectionModel.setSelectedSub2APITargetGroupID(groupID)
            },
            onSub2APIRefreshIntervalChange: { interval in
                connectionModel.setSelectedSub2APIRefreshInterval(interval)
            },
            onSub2APIBearerKeyChange: { bearerKey in
                connectionModel.setSelectedSub2APIBearerKey(bearerKey)
            }
        )
            .background {
                WindowSizeConfigurator(
                    minimumContentSize: windowContentMinimumSize,
                    maximumContentSize: windowContentMaximumSize
                )
            }
            .task {
                connectionModel.checkOnLaunch()
            }
            .onAppear {
                BrightnessAdjustmentRuntime.shared.register(connectionModel)
            }
            .onDisappear {
                BrightnessAdjustmentRuntime.shared.unregister(connectionModel)
            }
            .alert(item: $connectionModel.alert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .destructive(Text("退出")) {
                        connectionModel.quit()
                    },
                    secondaryButton: .default(Text("重试")) {
                        connectionModel.retry()
                    }
                )
            }
    }
}

private struct WindowSizeConfigurator: NSViewRepresentable {
    let minimumContentSize: CGSize
    let maximumContentSize: CGSize

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configureWindow(for: view)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            configureWindow(for: view)
        }
    }

    private func configureWindow(for view: NSView) {
        guard let window = view.window else {
            return
        }

        window.contentMinSize = minimumContentSize
        window.contentMaxSize = maximumContentSize
    }
}

#Preview {
    RootView(discovery: PreviewH200Discovery(), syncer: PreviewH200DeckSyncer())
}

private struct PreviewH200Discovery: H200Discovering {
    func discoverH200() -> H200DiscoveryResult {
        .connected(H200DeviceIdentity(
            vendorID: H200DeviceTarget.vendorID,
            productID: H200DeviceTarget.productID,
            locationID: 0x01124300,
            primaryUsagePage: H200DeviceTarget.primaryUsagePage,
            primaryUsage: H200DeviceTarget.primaryUsage,
            maxInputReportSize: H200DeviceTarget.reportSize,
            maxOutputReportSize: H200DeviceTarget.reportSize,
            serialNumber: "preview",
            manufacturer: "rockchip",
            product: ""
        ))
    }
}

private struct PreviewH200DeckSyncer: H200DeckSyncing {
    func sendStartupPackage(displays: [DeckKeyDisplay]) -> H200DeckSyncResult {
        .success(H200DeckSyncSummary(payloadByteCount: 4096, packetCount: 4, displayCount: displays.count))
    }
}
