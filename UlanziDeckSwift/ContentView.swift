import AppKit
import CoreImage.CIFilterBuiltins
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var brightnessDraftPercent: Int?
    @State var activeParameterFocusField: ParameterFocusField?
    @State var folderNameDraft: ParameterNameDraft?
    @State var fileNameDraft: ParameterNameDraft?
    @State var smbServerNameDraft: ParameterNameDraft?
    @FocusState var focusedParameterField: ParameterFocusField?

    enum ParameterFocusField: Hashable {
        case folderName
        case fileName
        case smbServerName
    }

    struct ParameterNameDraft: Equatable {
        let keyID: Int
        let originalNormalizedText: String
        var text: String
    }

    let connectedDevice: H200DeviceIdentity?
    let brightnessPercent: Int
    let interactionState: DeckGridInteractionState
    let mihoyoLoginState: MihoyoLoginState
    let buttonBackgroundDimmingEnabled: Bool
    let onKeySelection: (Int) -> Void
    let onKeyFunctionDeletion: (Int) -> Void
    let onKeyDisplayModeSelection: (Int, DeckKeyDisplayMode) -> Void
    let onKeySwap: (Int, Int) -> Void
    let onFunctionSelection: (DeckKeyFunction) -> Void
    let onTallyDefaultValueChange: (Int) -> Void
    let onFolderPathSelection: (DeckKeyOpenFolderConfiguration) -> Void
    let onFolderNamePreview: (Int, String) -> Void
    let onFolderNameChange: (Int, String) -> Void
    let onFilePathSelection: (DeckKeyOpenFileConfiguration) -> Void
    let onFileNamePreview: (Int, String) -> Void
    let onFileNameChange: (Int, String) -> Void
    let onFileIconBlurChange: (Int, Bool) -> Void
    let onSMBServerAddressChange: (String) -> Void
    let onSMBServerNamePreview: (Int, String) -> Void
    let onSMBServerNameChange: (Int, String) -> Void
    let onBrightnessPercentPreview: (Int) -> Void
    let onBrightnessPercentCommit: (Int) -> Void
    let onSub2APIBaseURLChange: (String) -> Void
    let onSub2APITargetGroupIDChange: (Int) -> Void
    let onSub2APIGroupListRefresh: () -> Void
    let onSub2APIRefreshIntervalChange: (Int) -> Void
    let onSub2APIBearerKeyChange: (String) -> Void
    let onSub2APIServiceNameChange: (String) -> Void
    let onSub2APIGroupNameChange: (String) -> Void
    let onMihoyoQRCodeLoginRequest: () -> Void
    let onMihoyoGameRefreshIntervalChange: (Int) -> Void
    let onMihoyoGameStatusRefresh: () -> Void
    let onButtonBackgroundDimmingToggle: () -> Void

    private let layout = DeckGridLayout.h200Prototype
    private let previewLayoutMetrics = DeckPreviewLayoutMetrics.h200
    private let minimumWindowWidth: CGFloat = 880
    private let functionSidebarMinimumWidth: CGFloat = 250
    private let functionSidebarPreferredWidth: CGFloat = 270
    private let functionSidebarMaximumWidth: CGFloat = 288

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                header(windowSize: geometry.size)
                Divider()
                workbench
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: minimumWindowWidth, minHeight: 674)
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: focusedParameterField) { _, newFocus in
            parameterFocusChanged(to: newFocus)
        }
        .onChange(of: interactionState.selectedKeyID) { _, _ in
            selectedKeyChangedDuringParameterEditing()
        }
    }

    private var deckPreviewAreaHeight: CGFloat {
        CGFloat(previewLayoutMetrics.previewAreaHeight(for: layout))
    }

    private var deckPreviewAreaMinimumWidth: CGFloat {
        CGFloat(previewLayoutMetrics.previewAreaMinimumWidth(for: layout))
    }

    private var previewGridMetrics: DeckPreviewGridMetrics {
        previewLayoutMetrics.gridMetrics
    }

    private var previewOuterHorizontalPadding: CGFloat {
        CGFloat(previewLayoutMetrics.outerHorizontalPadding)
    }

    private var previewOuterVerticalPadding: CGFloat {
        CGFloat(previewLayoutMetrics.outerVerticalPadding)
    }

    private var previewContentTopPadding: CGFloat {
        CGFloat(previewLayoutMetrics.contentTopPadding)
    }

    private var previewContentBottomPadding: CGFloat {
        CGFloat(previewLayoutMetrics.contentBottomPadding)
    }

    private var previewInnerPadding: CGFloat {
        CGFloat(previewLayoutMetrics.innerPadding)
    }

    private var previewPageSpacing: CGFloat {
        CGFloat(previewLayoutMetrics.pageSpacing)
    }

    private var pageSelectorHeight: CGFloat {
        CGFloat(previewLayoutMetrics.pageSelectorHeight)
    }

    private var previewGridSpacing: CGFloat {
        CGFloat(previewGridMetrics.spacing)
    }

    private var deckSurfaceWidth: CGFloat {
        CGFloat(previewLayoutMetrics.deckSurfaceWidth(for: layout))
    }

    private var deckSurfaceHeight: CGFloat {
        CGFloat(previewLayoutMetrics.deckSurfaceHeight(for: layout))
    }

    private var previewGridContentWidth: CGFloat {
        CGFloat(previewLayoutMetrics.gridContentWidth(for: layout))
    }

    private var previewGridContentHeight: CGFloat {
        CGFloat(previewLayoutMetrics.gridContentHeight(for: layout))
    }

    private func header(windowSize: CGSize) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Ulanzi Deck H200")
                    .font(.title.bold())

                HStack(spacing: 12) {
                    Text(layout.name)

                    Text("宽 \(Int(windowSize.width)) 高 \(Int(windowSize.height))")
                        .font(.caption.monospacedDigit())
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 16) {
                buttonBackgroundDimmingToggle
                brightnessControl
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
    }

    private var brightnessPercentSliderBinding: Binding<Double> {
        Binding(
            get: {
                Double(displayedBrightnessPercent)
            },
            set: { value in
                let percent = Int(value.rounded())
                brightnessDraftPercent = percent
                onBrightnessPercentPreview(percent)
            }
        )
    }

    private var displayedBrightnessPercent: Int {
        brightnessDraftPercent ?? brightnessPercent
    }

    private var brightnessControl: some View {
        HStack(spacing: 8) {
            Image(systemName: "sun.max")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            Slider(
                value: brightnessPercentSliderBinding,
                in: 0...100
            ) { isEditing in
                guard !isEditing else {
                    return
                }

                onBrightnessPercentCommit(displayedBrightnessPercent)
                brightnessDraftPercent = nil
            }
                .frame(width: 150)
                .disabled(connectedDevice == nil)

            Text("\(displayedBrightnessPercent)%")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 38, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("亮度")
        .accessibilityValue("\(displayedBrightnessPercent)%")
    }

    private var buttonBackgroundDimmingToggle: some View {
        Button {
            onButtonBackgroundDimmingToggle()
        } label: {
            Label(
                buttonBackgroundDimmingEnabled ? "背景已降亮" : "背景原亮度",
                systemImage: buttonBackgroundDimmingEnabled ? "circle.lefthalf.filled" : "circle"
            )
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(buttonBackgroundDimmingEnabled ? .accentColor : .secondary)
        .help(buttonBackgroundDimmingEnabled ? "按钮背景已降低亮度" : "按钮背景使用原始亮度")
        .accessibilityLabel("降低按钮背景亮度")
        .accessibilityValue(buttonBackgroundDimmingEnabled ? "已开启" : "已关闭")
    }

    private var workbench: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    deckPreviewArea
                    Divider()
                    parameterPanel
                }
                .frame(minWidth: deckPreviewAreaMinimumWidth)
                .frame(maxHeight: .infinity, alignment: .top)

                Divider()

                functionSidebar
                    .frame(
                        minWidth: functionSidebarMinimumWidth,
                        idealWidth: functionSidebarPreferredWidth,
                        maxWidth: functionSidebarMaximumWidth
                    )
                    .frame(height: geometry.size.height)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
    }

    private var deckPreviewArea: some View {
        VStack(spacing: previewPageSpacing) {
            deckSurface
            pageSelector
        }
        .padding(.horizontal, previewOuterHorizontalPadding)
        .padding(.vertical, previewOuterVerticalPadding)
        .padding(.top, previewContentTopPadding)
        .padding(.bottom, previewContentBottomPadding)
        .frame(maxWidth: .infinity)
        .frame(height: deckPreviewAreaHeight, alignment: .top)
    }

    private var deckSurface: some View {
        VStack(spacing: previewGridSpacing) {
            ForEach(Array(layout.rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: previewGridSpacing) {
                    ForEach(row) { key in
                        DeckKeyButton(
                            display: interactionState.display(
                                for: key,
                                buttonBackgroundDimmingEnabled: buttonBackgroundDimmingEnabled
                            ),
                            metrics: previewGridMetrics
                        ) {
                            onKeySelection(key.id)
                        } deleteAction: {
                            onKeyFunctionDeletion(key.id)
                        } displayModeSelectionAction: { displayMode in
                            onKeyDisplayModeSelection(key.id, displayMode)
                        } swapAction: { sourceKeyID, targetKeyID in
                            onKeySwap(sourceKeyID, targetKeyID)
                        }
                    }
                }
                .frame(width: previewGridContentWidth)
            }
        }
        .padding(previewInnerPadding)
        .frame(width: deckSurfaceWidth, height: deckSurfaceHeight)
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
        .frame(height: pageSelectorHeight)
        .background(Color(nsColor: .controlBackgroundColor), in: Capsule())
    }

    private var functionSidebar: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(functionSections) { section in
                    FunctionSectionCard(
                        section: section,
                        selectedFunction: selectedConfiguration?.function,
                        onFunctionSelection: onFunctionSelection
                    )
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
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
                ScrollView(.vertical) {
                    parameterContent(for: selectedConfiguration)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text("选择一个按键")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .frame(minHeight: 174, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .windowBackgroundColor))
    }

}

struct FunctionSection: Identifiable {
    let title: String
    let systemImageName: String
    let functions: [DeckKeyFunction]

    var id: String {
        title
    }
}

private struct FunctionSectionCard: View {
    let section: FunctionSection
    let selectedFunction: DeckKeyFunction?
    let onFunctionSelection: (DeckKeyFunction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: section.systemImageName)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 22)

                Text(section.title)
                    .font(.headline.weight(.semibold))

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(section.functions, id: \.self) { function in
                    FunctionRow(
                        function: function,
                        isSelected: selectedFunction == function
                    ) {
                        onFunctionSelection(function)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        }
    }
}

private struct FunctionRow: View {
    let function: DeckKeyFunction
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

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
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isHovered && !isSelected ? Color.white.opacity(0.72) : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityLabel(function.title)
        .accessibilityValue(isSelected ? "已选中" : "未选中")
    }
}

private struct DeckKeyButton: View {
    let display: DeckKeyDisplay
    let metrics: DeckPreviewGridMetrics
    let action: () -> Void
    let deleteAction: () -> Void
    let displayModeSelectionAction: (DeckKeyDisplayMode) -> Void
    let swapAction: (Int, Int) -> Void

    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: action) {
                DeckKeyRenderedImage(display: display, metrics: metrics)
                    .equatable()
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(display.isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                    }
                    .shadow(color: .black.opacity(0.22), radius: 7, y: 4)
            }
            .buttonStyle(.plain)
            .focusable(false)

            if display.isWide && display.displayMode != .function {
                displayModeBadge
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .allowsHitTesting(false)
            }

            if display.isWide && (isHovered || display.isSelected) {
                displayModeMenu
                    .padding(7)
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button(role: .destructive, action: deleteAction) {
                Label("删除", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("设备按键 \(display.id)")
        .accessibilityValue(accessibilityValue)
        .modifier(SquareKeyDragSwapModifier(
            isEnabled: !display.isWide,
            keyID: display.id,
            swapAction: swapAction
        ))
    }

    private var accessibilityValue: String {
        let content = display.title.isEmpty ? "无功能" : "\(display.title)，\(display.subtitle)"
        guard display.isWide, display.displayMode != .function else {
            return content
        }

        return "\(display.displayMode.title)，\(content)"
    }

    private var displayModeBadge: some View {
        Label(display.displayMode.title, systemImage: display.displayMode.systemImageName)
            .font(.system(size: 10, weight: .semibold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(.black.opacity(0.62), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            }
    }

    private var displayModeMenu: some View {
        Menu {
            ForEach(DeckKeyDisplayMode.allCases) { displayMode in
                Button {
                    displayModeSelectionAction(displayMode)
                } label: {
                    Label(displayMode.title, systemImage: displayMode.systemImageName)
                }
                .disabled(displayMode == display.displayMode)
            }
        } label: {
            Image(systemName: "chevron.down.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.white, Color.black.opacity(0.48))
                .frame(width: 24, height: 24)
                .contentShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(.plain)
        .help("选择小窗显示")
    }
}

private struct SquareKeyDragSwapModifier: ViewModifier {
    let isEnabled: Bool
    let keyID: Int
    let swapAction: (Int, Int) -> Void

    @State private var isDropTargeted = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            isDropTargeted ? Color.accentColor.opacity(0.88) : Color.clear,
                            lineWidth: 2
                        )
                        .allowsHitTesting(false)
                }
                .onDrag {
                    NSItemProvider(object: "\(keyID)" as NSString)
                }
                .onDrop(of: [UTType.text], isTargeted: $isDropTargeted) { providers in
                    guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else {
                        return false
                    }

                    provider.loadObject(ofClass: NSString.self) { object, _ in
                        guard let value = object as? NSString,
                              let sourceKeyID = Int(value as String),
                              sourceKeyID != keyID
                        else {
                            return
                        }

                        DispatchQueue.main.async {
                            swapAction(sourceKeyID, keyID)
                        }
                    }
                    return true
                }
        } else {
            content
        }
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

struct MihoyoQRCodeView: View {
    let payload: String

    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        if let image = makeImage() {
            Image(nsImage: image)
                .resizable()
                .interpolation(.none)
                .aspectRatio(1, contentMode: .fit)
                .accessibilityLabel("米游社登录二维码")
        } else {
            Image(systemName: "qrcode")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.secondary)
                .accessibilityLabel("二维码生成失败")
        }
    }

    private func makeImage() -> NSImage? {
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else {
            return nil
        }

        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: 256, height: 256))
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
        brightnessPercent: DeckBrightnessConfiguration.defaultPercent,
        interactionState: DeckGridInteractionState(layout: .h200Prototype),
        mihoyoLoginState: .notLoggedIn,
        buttonBackgroundDimmingEnabled: true,
        onKeySelection: { _ in },
        onKeyFunctionDeletion: { _ in },
        onKeyDisplayModeSelection: { _, _ in },
        onKeySwap: { _, _ in },
        onFunctionSelection: { _ in },
        onTallyDefaultValueChange: { _ in },
        onFolderPathSelection: { _ in },
        onFolderNamePreview: { _, _ in },
        onFolderNameChange: { _, _ in },
        onFilePathSelection: { _ in },
        onFileNamePreview: { _, _ in },
        onFileNameChange: { _, _ in },
        onFileIconBlurChange: { _, _ in },
        onSMBServerAddressChange: { _ in },
        onSMBServerNamePreview: { _, _ in },
        onSMBServerNameChange: { _, _ in },
        onBrightnessPercentPreview: { _ in },
        onBrightnessPercentCommit: { _ in },
        onSub2APIBaseURLChange: { _ in },
        onSub2APITargetGroupIDChange: { _ in },
        onSub2APIGroupListRefresh: {},
        onSub2APIRefreshIntervalChange: { _ in },
        onSub2APIBearerKeyChange: { _ in },
        onSub2APIServiceNameChange: { _ in },
        onSub2APIGroupNameChange: { _ in },
        onMihoyoQRCodeLoginRequest: {},
        onMihoyoGameRefreshIntervalChange: { _ in },
        onMihoyoGameStatusRefresh: {},
        onButtonBackgroundDimmingToggle: {}
    )
}
