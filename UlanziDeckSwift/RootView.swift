import SwiftUI

struct RootView: View {
    @StateObject private var connectionModel: H200ConnectionModel

    init(
        discovery: H200Discovering = H200HIDDiscovery(),
        syncer: H200DeckSyncing = H200HIDDeckSyncer(),
        configurationStore: DeckConfigurationStoring = UserDefaultsDeckConfigurationStore()
    ) {
        _connectionModel = StateObject(wrappedValue: H200ConnectionModel(
            discovery: discovery,
            syncer: syncer,
            configurationStore: configurationStore
        ))
    }

    var body: some View {
        ContentView(
            connectedDevice: connectionModel.connectedDevice,
            syncSummary: connectionModel.syncSummary,
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
            }
        )
            .task {
                connectionModel.checkOnLaunch()
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
