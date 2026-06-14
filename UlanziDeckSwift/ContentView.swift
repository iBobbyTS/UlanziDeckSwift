import SwiftUI

struct ContentView: View {
    let connectedDevice: H200DeviceIdentity?
    let syncSummary: H200DeckSyncSummary?
    let interactionState: DeckGridInteractionState
    let onKeyPress: (Int) -> Void

    private let layout = DeckGridLayout.h200Prototype

    var body: some View {
        VStack(spacing: 24) {
            header
            deckSurface
            statusBar
        }
        .padding(32)
        .frame(minWidth: 620, minHeight: 520)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Ulanzi Deck H200")
                    .font(.title.bold())

                Text("14 个按键，本地交互原型")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(layout.name)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(connectionLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(connectedDevice == nil ? Color.secondary : Color.green)
            }
        }
    }

    private var deckSurface: some View {
        VStack(spacing: 16) {
            ForEach(Array(layout.rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 16) {
                    ForEach(row) { key in
                        DeckKeyButton(
                            display: interactionState.display(for: key)
                        ) {
                            withAnimation(.snappy(duration: 0.18)) {
                                onKeyPress(key.id)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(28)
        .animation(.snappy(duration: 0.18), value: interactionState)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.linearGradient(
                    colors: [
                        Color(nsColor: .controlBackgroundColor),
                        Color(nsColor: .underPageBackgroundColor)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.14), radius: 18, y: 10)
    }

    private var statusBar: some View {
        HStack {
            if let selectedKeyID = interactionState.selectedKeyID {
                Text("按键 \(selectedKeyID) 已按下")
                    .font(.headline)

                Spacer()

                Text("点击次数：\(interactionState.tapCount(for: selectedKeyID))")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                Text("按下任意格子以测试响应。")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private extension ContentView {
    var connectionLabel: String {
        guard let connectedDevice else {
            return "正在检测 H200"
        }

        if connectedDevice.serialNumber.isEmpty {
            return syncSummaryLabel ?? "H200 已连接"
        }

        if let syncSummaryLabel {
            return "H200 \(connectedDevice.serialNumber)，\(syncSummaryLabel)"
        }

        return "H200 \(connectedDevice.serialNumber)"
    }

    var syncSummaryLabel: String? {
        guard let syncSummary else {
            return nil
        }

        return "已同步 \(syncSummary.displayCount) 个格子"
    }
}

private struct DeckKeyButton: View {
    let display: DeckKeyDisplay
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(display.title)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()

                Text(display.subtitle)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(display.isSelected ? .white.opacity(0.82) : .secondary)
            }
            .frame(width: buttonWidth, height: 82)
            .foregroundStyle(display.isSelected ? .white : .primary)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(display.isSelected ? Color.accentColor : Color(nsColor: .textBackgroundColor))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(display.isSelected ? Color.white.opacity(0.35) : Color(nsColor: .separatorColor), lineWidth: 1)
            }
            .scaleEffect(display.isSelected ? 1.04 : 1)
            .shadow(color: .black.opacity(display.isSelected ? 0.24 : 0.16), radius: display.isSelected ? 12 : 7, y: display.isSelected ? 7 : 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("设备按键 \(display.id)")
        .accessibilityValue(display.subtitle)
    }

    private var buttonWidth: CGFloat {
        82 * CGFloat(display.columnSpan) + 16 * CGFloat(display.columnSpan - 1)
    }
}

#Preview {
    ContentView(connectedDevice: H200DeviceIdentity(
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
    ), syncSummary: H200DeckSyncSummary(payloadByteCount: 4096, packetCount: 4, displayCount: 14), interactionState: DeckGridInteractionState(layout: .h200Prototype)) { _ in }
}
