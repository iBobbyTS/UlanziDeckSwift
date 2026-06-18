import AppKit
import CoreImage.CIFilterBuiltins
import SwiftUI

struct ContentView: View {
    @State private var brightnessDraftPercent: Int?

    let connectedDevice: H200DeviceIdentity?
    let brightnessPercent: Int
    let interactionState: DeckGridInteractionState
    let mihoyoLoginState: MihoyoLoginState
    let onKeySelection: (Int) -> Void
    let onKeyFunctionDeletion: (Int) -> Void
    let onFunctionSelection: (DeckKeyFunction) -> Void
    let onTallyDefaultValueChange: (Int) -> Void
    let onFolderPathSelection: (String) -> Void
    let onSMBServerAddressChange: (String) -> Void
    let onBrightnessPercentPreview: (Int) -> Void
    let onBrightnessPercentCommit: (Int) -> Void
    let onSub2APIBaseURLChange: (String) -> Void
    let onSub2APITargetGroupIDChange: (Int) -> Void
    let onSub2APIRefreshIntervalChange: (Int) -> Void
    let onSub2APIBearerKeyChange: (String) -> Void
    let onMihoyoQRCodeLoginRequest: () -> Void
    let onMihoyoGameStatusRefresh: () -> Void

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
                brightnessControl
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
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
                        DeckKeyButton(display: interactionState.display(for: key), metrics: previewGridMetrics) {
                            onKeySelection(key.id)
                        } deleteAction: {
                            onKeyFunctionDeletion(key.id)
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

    @ViewBuilder
    private func parameterContent(for configuration: DeckKeyConfiguration) -> some View {
        switch configuration.function {
        case .none, .brightness:
            HStack(alignment: .top, spacing: 28) {
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
            HStack(alignment: .top, spacing: 28) {
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
            HStack(alignment: .top, spacing: 28) {
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

        case .connectSMBServer:
            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("功能")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Label(configuration.function.title, systemImage: configuration.function.systemImageName)
                        .font(.callout.weight(.medium))
                }
                .frame(width: 150, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    Text("服务器地址")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 0) {
                        Text("smb://")
                            .font(.callout.monospaced())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 9)
                            .frame(height: 24)
                            .background(Color(nsColor: .controlBackgroundColor))

                        TextField("server.local/share", text: selectedSMBServerAddressBinding)
                            .textFieldStyle(.roundedBorder)
                    }
                    .frame(maxWidth: 360, alignment: .leading)

                    Text("只填写服务器和共享名，例如 server.local/share。连接时会使用系统认证窗口。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

        case .sub2API:
            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("功能")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Label(configuration.function.title, systemImage: configuration.function.systemImageName)
                        .font(.callout.weight(.medium))
                }
                .frame(width: 150, alignment: .leading)

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Base URL")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        TextField("your-api.example.com", text: selectedSub2APIBaseURLBinding)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("目标分组 ID")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        TextField("目标分组 ID", value: selectedSub2APITargetGroupIDBinding, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 140)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("刷新间隔（秒）")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 10) {
                            TextField("刷新间隔", value: selectedSub2APIRefreshIntervalBinding, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 96)

                            Stepper("刷新间隔", value: selectedSub2APIRefreshIntervalBinding, in: 5...3600)
                                .labelsHidden()
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Bearer Key")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        TextField("Bearer Key", text: selectedSub2APIBearerKeyBinding)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .frame(maxWidth: 360, alignment: .leading)

                Spacer()
            }

        case .genshinStatus, .starRailStatus, .zenlessZoneStatus:
            mihoyoGameParameterContent(for: configuration)
        }
    }
}

private extension ContentView {
    var functionSections: [FunctionSection] {
        [
            FunctionSection(
                title: "数字",
                systemImageName: "number.square",
                functions: [.tally]
            ),
            FunctionSection(
                title: "访达",
                systemImageName: "folder",
                functions: [.openFolder, .connectSMBServer]
            ),
            FunctionSection(
                title: "网站",
                systemImageName: "globe",
                functions: [.sub2API]
            ),
            FunctionSection(
                title: "游戏",
                systemImageName: "gamecontroller",
                functions: [.genshinStatus, .starRailStatus, .zenlessZoneStatus]
            ),
        ]
    }

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

    var selectedSMBServerAddressBinding: Binding<String> {
        Binding(
            get: {
                selectedConfiguration?.smbServer.address ?? ""
            },
            set: { address in
                onSMBServerAddressChange(address)
            }
        )
    }

    var selectedSub2APIBaseURLBinding: Binding<String> {
        Binding(
            get: {
                selectedConfiguration?.sub2API.baseURL ?? ""
            },
            set: { baseURL in
                onSub2APIBaseURLChange(baseURL)
            }
        )
    }

    var selectedSub2APITargetGroupIDBinding: Binding<Int> {
        Binding(
            get: {
                selectedConfiguration?.sub2API.targetGroupID ?? 0
            },
            set: { groupID in
                onSub2APITargetGroupIDChange(groupID)
            }
        )
    }

    var selectedSub2APIRefreshIntervalBinding: Binding<Int> {
        Binding(
            get: {
                selectedConfiguration?.sub2API.refreshInterval ?? 30
            },
            set: { interval in
                onSub2APIRefreshIntervalChange(interval)
            }
        )
    }

    var selectedSub2APIBearerKeyBinding: Binding<String> {
        Binding(
            get: {
                selectedConfiguration?.sub2API.bearerKey ?? ""
            },
            set: { bearerKey in
                onSub2APIBearerKeyChange(bearerKey)
            }
        )
    }

    var brightnessPercentSliderBinding: Binding<Double> {
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

    var displayedBrightnessPercent: Int {
        brightnessDraftPercent ?? brightnessPercent
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

    func mihoyoGameParameterContent(for configuration: DeckKeyConfiguration) -> some View {
        HStack(alignment: .top, spacing: 28) {
            VStack(alignment: .leading, spacing: 8) {
                Text("功能")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Label(configuration.function.title, systemImage: configuration.function.systemImageName)
                    .font(.callout.weight(.medium))
            }
            .frame(width: 150, alignment: .leading)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: mihoyoLoginStateIconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(mihoyoLoginStateColor)
                        .frame(width: 18)

                    Text(mihoyoLoginState.statusText)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(mihoyoLoginStateColor)

                    Spacer(minLength: 0)
                }

                if let qrCodeURLString = mihoyoLoginState.qrCodeURLString {
                    MihoyoQRCodeView(payload: qrCodeURLString)
                        .frame(width: 132, height: 132)
                        .padding(8)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                        }
                }

                if let gameStatus = configuration.mihoyoGame.lastResult {
                    mihoyoGameStatusSummary(gameStatus)
                }
            }
            .frame(maxWidth: 360, alignment: .leading)

            VStack(alignment: .leading, spacing: 10) {
                Button(action: onMihoyoQRCodeLoginRequest) {
                    Label(mihoyoLoginState.loginButtonTitle, systemImage: "qrcode")
                }
                .buttonStyle(.borderedProminent)
                .disabled(mihoyoLoginState == .creatingQRCode)

                Button(action: onMihoyoGameStatusRefresh) {
                    Label("刷新状态", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(!mihoyoLoginState.canRefreshGameStatus)
            }

            Spacer()
        }
    }

    @ViewBuilder
    func mihoyoGameStatusSummary(_ result: MihoyoGameStatusResult) -> some View {
        switch result {
        case let .success(status):
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                GridRow {
                    Text("角色")
                        .foregroundStyle(.secondary)
                    Text(status.role.displayName)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                GridRow {
                    Text(status.staminaName)
                        .foregroundStyle(.secondary)
                    Text(status.staminaValueText)
                        .monospacedDigit()
                }
                GridRow {
                    Text(status.dailyName)
                        .foregroundStyle(.secondary)
                    Text(status.dailyValueText)
                        .monospacedDigit()
                }
                GridRow {
                    Text("恢复")
                        .foregroundStyle(.secondary)
                    Text(status.recoverDescription)
                }
                GridRow {
                    Text("来源")
                        .foregroundStyle(.secondary)
                    Text(status.source.displayName)
                }
            }
            .font(.caption)

            if status.staminaMayBeCappedBySource {
                Label("该接口可能返回受限体力值", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .loginRequired:
            Label("需要登录后查询", systemImage: "person.crop.circle.badge.exclamationmark")
                .font(.caption)
                .foregroundStyle(.secondary)
        case let .loginExpired(message):
            Label(message, systemImage: "person.crop.circle.badge.xmark")
                .font(.caption)
                .foregroundStyle(.red)
        case let .noBoundRole(game):
            Label("未找到 \(game.displayName) 绑定角色", systemImage: "person.crop.circle.badge.questionmark")
                .font(.caption)
                .foregroundStyle(.secondary)
        case let .networkError(message):
            Label(message, systemImage: "wifi.exclamationmark")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    var mihoyoLoginStateIconName: String {
        switch mihoyoLoginState {
        case .notLoggedIn:
            return "person.crop.circle.badge.exclamationmark"
        case .creatingQRCode:
            return "qrcode"
        case .waitingForScan:
            return "qrcode.viewfinder"
        case .scanned:
            return "checkmark.circle"
        case .loggedIn:
            return "person.crop.circle.fill.badge.checkmark"
        case .failed:
            return "xmark.octagon"
        case .expired:
            return "clock.badge.exclamationmark"
        }
    }

    var mihoyoLoginStateColor: Color {
        switch mihoyoLoginState {
        case .loggedIn:
            return .green
        case .failed, .expired:
            return .red
        case .notLoggedIn, .creatingQRCode, .waitingForScan, .scanned:
            return .secondary
        }
    }

}

private struct FunctionSection: Identifiable {
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

private struct MihoyoQRCodeView: View {
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
        onKeySelection: { _ in },
        onKeyFunctionDeletion: { _ in },
        onFunctionSelection: { _ in },
        onTallyDefaultValueChange: { _ in },
        onFolderPathSelection: { _ in },
        onSMBServerAddressChange: { _ in },
        onBrightnessPercentPreview: { _ in },
        onBrightnessPercentCommit: { _ in },
        onSub2APIBaseURLChange: { _ in },
        onSub2APITargetGroupIDChange: { _ in },
        onSub2APIRefreshIntervalChange: { _ in },
        onSub2APIBearerKeyChange: { _ in },
        onMihoyoQRCodeLoginRequest: {},
        onMihoyoGameStatusRefresh: {}
    )
}
