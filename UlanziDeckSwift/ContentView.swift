import SwiftUI

struct ContentView: View {
    let connectedDevice: H200DeviceIdentity?

    private let layout = DeckGridLayout.h200Prototype

    @State private var interactionState = DeckGridInteractionState(layout: .h200Prototype)

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
                            number: key.id,
                            tapCount: interactionState.tapCount(for: key.id),
                            isSelected: interactionState.selectedKeyID == key.id
                        ) {
                            withAnimation(.snappy(duration: 0.18)) {
                                interactionState.press(keyID: key.id)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(28)
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
            return "H200 已连接"
        }

        return "H200 \(connectedDevice.serialNumber)"
    }
}

private struct DeckKeyButton: View {
    let number: Int
    let tapCount: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text("\(number)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()

                Text(tapCount == 0 ? "就绪" : "\(tapCount) 次")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? .white.opacity(0.82) : .secondary)
            }
            .frame(width: 82, height: 82)
            .foregroundStyle(isSelected ? .white : .primary)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color(nsColor: .textBackgroundColor))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? Color.white.opacity(0.35) : Color(nsColor: .separatorColor), lineWidth: 1)
            }
            .scaleEffect(isSelected ? 1.04 : 1)
            .shadow(color: .black.opacity(isSelected ? 0.24 : 0.16), radius: isSelected ? 12 : 7, y: isSelected ? 7 : 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("设备按键 \(number)")
        .accessibilityValue("点击次数 \(tapCount)")
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
    ))
}
