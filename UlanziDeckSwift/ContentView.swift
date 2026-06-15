import AppKit
import SwiftUI

struct ContentView: View {
    let connectedDevice: H200DeviceIdentity?
    let syncSummary: H200DeckSyncSummary?
    let interactionState: DeckGridInteractionState
    let onKeySelection: (Int) -> Void
    let onKeyFunctionDeletion: (Int) -> Void
    let onFunctionSelection: (DeckKeyFunction) -> Void
    let onTallyDefaultValueChange: (Int) -> Void
    let onFolderPathSelection: (String) -> Void
    let onBrightnessPercentChange: (Int) -> Void

    private let layout = DeckGridLayout.h200Prototype
    private let previewMetrics = DeckPreviewGridMetrics.h200

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            workbench
        }
        .frame(minWidth: 940, minHeight: 640)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Ulanzi Deck H200")
                    .font(.title.bold())

                Text(layout.name)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(connectionLabel)
                .font(.caption.monospacedDigit())
                .foregroundStyle(connectedDevice == nil ? Color.secondary : Color.green)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
    }

    private var workbench: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                deckPreviewArea
                Divider()
                parameterPanel
            }

            Divider()

            functionSidebar
                .frame(width: 270)
        }
    }

    private var deckPreviewArea: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 8)
            deckSurface
            pageSelector
            Spacer(minLength: 8)
        }
        .padding(28)
    }

    private var deckSurface: some View {
        VStack(spacing: CGFloat(previewMetrics.spacing)) {
            ForEach(Array(layout.rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: CGFloat(previewMetrics.spacing)) {
                    ForEach(row) { key in
                        DeckKeyButton(display: interactionState.display(for: key), metrics: previewMetrics) {
                            onKeySelection(key.id)
                        } deleteAction: {
                            onKeyFunctionDeletion(key.id)
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
                        Color(nsColor: .underPageBackgroundColor),
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

    private var pageSelector: some View {
        HStack(spacing: 0) {
            Text("1")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 22)
                .background(Color.accentColor, in: Capsule())

            Text("2")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 22)

            Image(systemName: "plus")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 22)
        }
        .padding(2)
        .background(Color(nsColor: .controlBackgroundColor), in: Capsule())
    }

    private var functionSidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("按键功能")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("基础")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(DeckKeyFunction.assignableCases, id: \.self) { function in
                    FunctionRow(
                        function: function,
                        isSelected: selectedConfiguration?.function == function
                    ) {
                        onFunctionSelection(function)
                    }
                }
            }

            Spacer()
        }
        .padding(18)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var parameterPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("功能参数")
                    .font(.headline)

                Spacer()

                if let selectedKeyID = interactionState.selectedKeyID {
                    Text("按键 \(selectedKeyID)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            if let selectedConfiguration {
                parameterContent(for: selectedConfiguration)
            } else {
                Text("选择一个按键")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .frame(height: 174, alignment: .top)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private func parameterContent(for configuration: DeckKeyConfiguration) -> some View {
        switch configuration.function {
        case .none:
            HStack(spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("功能")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Label(configuration.function.title, systemImage: configuration.function.systemImageName)
                        .font(.callout.weight(.medium))
                }
                .frame(width: 150, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    Text("参数")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text("无可配置参数")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

        case .tally:
            HStack(spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("功能")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Label(configuration.function.title, systemImage: configuration.function.systemImageName)
                        .font(.callout.weight(.medium))
                }
                .frame(width: 150, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    Text("当前值")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text("\(configuration.tally.value)")
                        .font(.title2.monospacedDigit().weight(.semibold))
                }
                .frame(width: 110, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    Text("默认数值")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        TextField("默认数值", value: selectedTallyDefaultValueBinding, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 96)

                        Stepper("默认数值", value: selectedTallyDefaultValueBinding, in: -999...999)
                            .labelsHidden()
                    }
                }

                Spacer()
            }

        case .openFolder:
            HStack(spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("功能")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Label(configuration.function.title, systemImage: configuration.function.systemImageName)
                        .font(.callout.weight(.medium))
                }
                .frame(width: 150, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    Text("文件夹")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(configuration.openFolder.path ?? "未选择文件夹")
                        .font(.callout)
                        .foregroundStyle(configuration.openFolder.path == nil ? Color.secondary : Color.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    chooseFolder()
                } label: {
                    Label("选择文件夹", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.bordered)

                Spacer()
            }

        case .brightness:
            HStack(spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("功能")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Label(configuration.function.title, systemImage: configuration.function.systemImageName)
                        .font(.callout.weight(.medium))
                }
                .frame(width: 150, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    Text("亮度")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text("\(configuration.brightness.percent)%")
                        .font(.title2.monospacedDigit().weight(.semibold))
                }
                .frame(width: 90, alignment: .leading)

                Slider(value: selectedBrightnessPercentSliderBinding, in: 0...100, step: 1)
                    .frame(width: 210)
                    .accessibilityLabel("亮度")

                Stepper("亮度", value: selectedBrightnessPercentBinding, in: 0...100)
                    .labelsHidden()

                Spacer()
            }
        }
    }
}

private extension ContentView {
    var selectedConfiguration: DeckKeyConfiguration? {
        guard let selectedKeyID = interactionState.selectedKeyID else {
            return nil
        }

        return interactionState.configuration(for: selectedKeyID)
    }

    var selectedTallyDefaultValueBinding: Binding<Int> {
        Binding(
            get: {
                selectedConfiguration?.tally.defaultValue ?? 0
            },
            set: { value in
                onTallyDefaultValueChange(value)
            }
        )
    }

    var selectedBrightnessPercentBinding: Binding<Int> {
        Binding(
            get: {
                selectedConfiguration?.brightness.percent ?? 50
            },
            set: { value in
                onBrightnessPercentChange(value)
            }
        )
    }

    var selectedBrightnessPercentSliderBinding: Binding<Double> {
        Binding(
            get: {
                Double(selectedBrightnessPercentBinding.wrappedValue)
            },
            set: { value in
                onBrightnessPercentChange(Int(value.rounded()))
            }
        )
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "选择文件夹"
        panel.prompt = "选择"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK,
              let url = panel.url
        else {
            return
        }

        onFolderPathSelection(url.path)
    }

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

private struct FunctionRow: View {
    let function: DeckKeyFunction
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: function.systemImageName)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 20)

                Text(function.title)
                    .font(.callout.weight(.medium))

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                }
            }
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.5) : Color(nsColor: .separatorColor), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(function.title)
    }
}

private struct DeckKeyButton: View {
    let display: DeckKeyDisplay
    let metrics: DeckPreviewGridMetrics
    let action: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        Button(action: action) {
            DeckKeyRenderedImage(display: display, metrics: metrics)
                .equatable()
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(display.isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                }
                .shadow(color: .black.opacity(0.22), radius: 7, y: 4)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .contextMenu {
            Button(role: .destructive, action: deleteAction) {
                Label("删除", systemImage: "trash")
            }
        }
        .accessibilityLabel("设备按键 \(display.id)")
        .accessibilityValue(display.title.isEmpty ? "无功能" : "\(display.title)，\(display.subtitle)")
    }
}

private struct DeckKeyRenderedImage: View, Equatable {
    let display: DeckKeyDisplay
    let metrics: DeckPreviewGridMetrics

    static func == (lhs: DeckKeyRenderedImage, rhs: DeckKeyRenderedImage) -> Bool {
        lhs.display.renderIdentity == rhs.display.renderIdentity
            && lhs.metrics == rhs.metrics
    }

    var body: some View {
        renderedImage
            .resizable()
            .interpolation(.high)
            .aspectRatio(aspectRatio, contentMode: .fit)
            .frame(width: buttonWidth, height: CGFloat(metrics.cellLength))
    }

    private var renderedImage: Image {
        let renderer = H200ButtonIconRenderer()
        guard let png = try? renderer.pngData(for: display),
              let image = NSImage(data: png)
        else {
            return Image(systemName: "xmark.square")
        }

        return Image(nsImage: image)
    }

    private var aspectRatio: CGFloat {
        CGFloat(display.devicePixelSize.width) / CGFloat(display.devicePixelSize.height)
    }

    private var buttonWidth: CGFloat {
        CGFloat(metrics.slotWidth(columnSpan: display.columnSpan))
    }
}

#Preview {
    ContentView(
        connectedDevice: H200DeviceIdentity(
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
        ),
        syncSummary: H200DeckSyncSummary(payloadByteCount: 4096, packetCount: 4, displayCount: 14),
        interactionState: DeckGridInteractionState(layout: .h200Prototype),
        onKeySelection: { _ in },
        onKeyFunctionDeletion: { _ in },
        onFunctionSelection: { _ in },
        onTallyDefaultValueChange: { _ in },
        onFolderPathSelection: { _ in },
        onBrightnessPercentChange: { _ in }
    )
}
