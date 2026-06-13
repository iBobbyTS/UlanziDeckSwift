import SwiftUI

struct RootView: View {
    @StateObject private var connectionModel: H200ConnectionModel

    init(discovery: H200Discovering = H200HIDDiscovery()) {
        _connectionModel = StateObject(wrappedValue: H200ConnectionModel(discovery: discovery))
    }

    var body: some View {
        ContentView(connectedDevice: connectionModel.connectedDevice)
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
    RootView(discovery: PreviewH200Discovery())
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
