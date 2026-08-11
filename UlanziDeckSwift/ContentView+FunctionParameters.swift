import AppKit
import SwiftUI
import UniformTypeIdentifiers

private enum ButtonBackgroundSelectionMode: Int {
    case image
    case allFiles
}

private final class ButtonBackgroundSelectionAccessory: NSObject {
    let view: NSView
    private let popupButton: NSPopUpButton
    private weak var panel: NSOpenPanel?

    var mode: ButtonBackgroundSelectionMode {
        ButtonBackgroundSelectionMode(rawValue: popupButton.indexOfSelectedItem) ?? .image
    }

    init(panel: NSOpenPanel) {
        self.panel = panel
        popupButton = NSPopUpButton()
        popupButton.addItem(withTitle: "图像")
        popupButton.addItem(withTitle: "所有文件")

        let label = NSTextField(labelWithString: "类型")
        label.alignment = .right

        let stackView = NSStackView(views: [label, popupButton])
        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.spacing = 8
        view = stackView

        super.init()

        popupButton.target = self
        popupButton.action = #selector(selectionChanged(_:))
        applyMode()
    }

    @objc private func selectionChanged(_ sender: NSPopUpButton) {
        applyMode()
    }

    private func applyMode() {
        switch mode {
        case .image:
            panel?.allowedContentTypes = [.image]
        case .allFiles:
            panel?.allowedContentTypes = []
        }
    }
}

extension ContentView {
    nonisolated static func shouldAutomaticallySelectDefaultCodexAuthFile(
        currentFunction: DeckKeyFunction?,
        selectedFunction: DeckKeyFunction
    ) -> Bool {
        currentFunction == DeckKeyFunction.none && selectedFunction == .codexUsage
    }

    @ViewBuilder
    func parameterContent(for configuration: DeckKeyConfiguration) -> some View {
        switch configuration.function {
        case .none, .brightness, .previousPage, .nextPage:
            HStack(alignment: .top, spacing: 28) {
                functionParameterColumn(for: configuration)

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

        case .pageBack:
            HStack(alignment: .top, spacing: 28) {
                functionParameterColumn(for: configuration)

                VStack(alignment: .leading, spacing: 8) {
                    Text("参数")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text("返回上一级页面，不可删除")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

        case .tally:
            HStack(alignment: .top, spacing: 28) {
                functionParameterColumn(for: configuration)

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
            localResourceParameterContent(
                configuration: configuration,
                resourceTitle: "文件夹",
                path: configuration.openFolder.path,
                emptyPathText: "未选择文件夹",
                needsReselection: configuration.openFolder.needsReselection,
                chooseButtonTitle: "选择文件夹",
                rechooseButtonTitle: "重新选择文件夹",
                chooseButtonSystemImage: "folder.badge.plus"
            ) {
                chooseFolder()
            }

        case .openFile:
            localResourceParameterContent(
                configuration: configuration,
                resourceTitle: "文件",
                path: configuration.openFile.path,
                emptyPathText: "未选择文件",
                needsReselection: configuration.openFile.needsReselection,
                chooseButtonTitle: "选择文件",
                rechooseButtonTitle: "重新选择文件",
                chooseButtonSystemImage: "doc.badge.plus"
            ) {
                chooseFile()
            }

        case .openWebPage:
            HStack(alignment: .top, spacing: 28) {
                functionParameterColumn(for: configuration)

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("网页地址")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        TextField("https://example.com", text: selectedWebPageURLBinding)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedParameterField, equals: .webPageURL)
                            .onSubmit {
                                focusedParameterField = nil
                            }

                        Text("按回车或结束编辑后会获取网页标题和图标。按下按钮时使用默认浏览器打开。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: 360, alignment: .leading)

                Spacer()
            }

        case .connectSMBServer:
            HStack(alignment: .top, spacing: 28) {
                functionParameterColumn(for: configuration)

                VStack(alignment: .leading, spacing: 12) {
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

                        Text("地址只填写服务器和共享名，例如 server.local/share。连接时会使用系统认证窗口。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()
            }

        case .pageFolder:
            HStack(alignment: .top, spacing: 28) {
                functionParameterColumn(for: configuration)

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

        case .sub2API:
            HStack(alignment: .top, spacing: 28) {
                functionParameterColumn(for: configuration)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("认证来源")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Picker("认证来源", selection: selectedSub2APIDataSourceBinding) {
                                Text("自定义").tag(String?.none)

                                ForEach(selectedSub2APIDataSourceReferenceOptions) { option in
                                    Text(option.title).tag(Optional(option.instanceID))
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Base URL")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            TextField("your-api.example.com", text: selectedSub2APIBaseURLBinding)
                                .textFieldStyle(.roundedBorder)
                                .disabled(selectedSub2APIDataSourceInstanceID != nil)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("认证信息")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            SecureField("认证信息", text: selectedSub2APIBearerKeyBinding)
                                .textFieldStyle(.roundedBorder)
                                .disabled(selectedSub2APIDataSourceInstanceID != nil)

                            Button("获取认证信息") {
                                copySub2APIAuthScript()
                            }
                            .font(.caption)
                            .disabled(selectedSub2APIDataSourceInstanceID != nil)
                        }
                    }

                    Divider()

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
                        .disabled(selectedSub2APIDataSourceInstanceID != nil)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("目标分组")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            Picker("目标分组", selection: selectedSub2APITargetGroupIDBinding) {
                                Text("未选择").tag(0)

                                ForEach(selectedSub2APIGroupOptions, id: \.groupID) { item in
                                    Text(sub2APIGroupOptionTitle(item))
                                        .tag(item.groupID)
                                }

                                if let fallbackGroupOption = selectedSub2APIFallbackGroupOption {
                                    Text(fallbackGroupOption.title)
                                        .tag(fallbackGroupOption.groupID)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Button("从服务器获取号池") {
                                onSub2APIGroupListRefresh()
                            }
                            .disabled(!canRefreshSelectedSub2APIGroupList)
                        }

                        if let statusText = selectedSub2APIGroupListStatusText {
                            Text(statusText)
                                .font(.caption)
                                .foregroundStyle(selectedSub2APIGroupListStatusIsError ? Color.red : Color.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    HStack(alignment: .top, spacing: 8) {
                        sub2APINameParameterRow(
                            label: "服务名",
                            placeholder: selectedSub2APIAutomaticServiceName,
                            text: selectedSub2APIServiceNameBinding
                        )
                        sub2APINameParameterRow(
                            label: "号池名",
                            placeholder: selectedSub2APIAutomaticGroupName,
                            text: selectedSub2APIGroupNameBinding
                        )
                    }
                }
                .frame(maxWidth: 360, alignment: .leading)

                Spacer()
            }

        case .sub2APIBalance:
            HStack(alignment: .top, spacing: 28) {
                functionParameterColumn(for: configuration)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("数据来源")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Picker("数据来源", selection: selectedSub2APIDataSourceBinding) {
                                Text("自定义").tag(String?.none)
                                ForEach(selectedSub2APIDataSourceReferenceOptions) { option in
                                    Text(option.title).tag(Optional(option.instanceID))
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(width: 150, alignment: .leading)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Base URL")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            TextField("your-api.example.com", text: selectedSub2APIBaseURLBinding)
                                .textFieldStyle(.roundedBorder)
                                .disabled(selectedSub2APIDataSourceInstanceID != nil)
                        }
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
                        .disabled(selectedSub2APIDataSourceInstanceID != nil)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("认证信息")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            SecureField("认证信息", text: selectedSub2APIBearerKeyBinding)
                                .textFieldStyle(.roundedBorder)
                                .disabled(selectedSub2APIDataSourceInstanceID != nil)
                            Button("获取认证信息") { copySub2APIAuthScript() }
                                .font(.caption)
                                .disabled(selectedSub2APIDataSourceInstanceID != nil)
                        }
                    }

                    Divider()
                    sub2APINameParameterRow(
                        label: "服务名",
                        placeholder: selectedSub2APIAutomaticServiceName,
                        text: selectedSub2APIServiceNameBinding
                    )
                    sub2APINameParameterRow(
                        label: "单位",
                        placeholder: "$",
                        text: selectedSub2APIBalanceUnitBinding
                    )
                }
                .frame(maxWidth: 360, alignment: .leading)

                Spacer()
            }

        case .codexUsage:
            codexUsageParameterContent(for: configuration)

        case .genshinStatus, .starRailStatus, .zenlessZoneStatus:
            mihoyoGameParameterContent(for: configuration)
        }
    }

    private func functionParameterColumn(for configuration: DeckKeyConfiguration) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("功能")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Label(configuration.function.title, systemImage: configuration.function.systemImageName)
                    .font(.callout.weight(.medium))
            }

            buttonVisualControls(for: configuration)
        }
        .frame(width: 170, alignment: .leading)
    }

    private func localResourceParameterContent(
        configuration: DeckKeyConfiguration,
        resourceTitle: String,
        path: String?,
        emptyPathText: String,
        needsReselection: Bool,
        chooseButtonTitle: String,
        rechooseButtonTitle: String,
        chooseButtonSystemImage: String,
        chooseAction: @escaping () -> Void
    ) -> some View {
        localResourceParameterContent(
            configuration: configuration,
            resourceTitle: resourceTitle,
            path: path,
            emptyPathText: emptyPathText,
            needsReselection: needsReselection,
            chooseButtonTitle: chooseButtonTitle,
            rechooseButtonTitle: rechooseButtonTitle,
            chooseButtonSystemImage: chooseButtonSystemImage,
            additionalContent: { EmptyView() },
            chooseAction: chooseAction
        )
    }

    private func localResourceParameterContent<AdditionalContent: View>(
        configuration: DeckKeyConfiguration,
        resourceTitle: String,
        path: String?,
        emptyPathText: String,
        needsReselection: Bool,
        chooseButtonTitle: String,
        rechooseButtonTitle: String,
        chooseButtonSystemImage: String,
        @ViewBuilder additionalContent: () -> AdditionalContent,
        chooseAction: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 28) {
            functionParameterColumn(for: configuration)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(resourceTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(path ?? emptyPathText)
                        .font(.callout)
                        .foregroundStyle(path == nil ? Color.secondary : Color.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if needsReselection {
                        Text("需要重新选择")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Button {
                chooseAction()
            } label: {
                Label(
                    needsReselection ? rechooseButtonTitle : chooseButtonTitle,
                    systemImage: chooseButtonSystemImage
                )
            }
            .buttonStyle(.bordered)

            additionalContent()

            Spacer()
        }
    }

    private func codexUsageParameterContent(for configuration: DeckKeyConfiguration) -> some View {
        HStack(alignment: .top, spacing: 28) {
            functionParameterColumn(for: configuration)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("认证来源")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Picker("认证来源", selection: selectedCodexUsageAuthSourceBinding) {
                        ForEach(CodexAuthSource.allCases) { source in
                            Text(source.title).tag(source)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 180, alignment: .leading)
                }

                if configuration.codexUsage.authSource == .authFile {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Codex auth.json")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(configuration.codexUsage.authFilePath ?? "未选择 auth.json")
                            .font(.callout)
                            .foregroundStyle(
                                configuration.codexUsage.authFilePath == nil
                                    ? Color.secondary
                                    : Color.primary
                            )
                            .lineLimit(1)
                            .truncationMode(.middle)

                        if configuration.codexUsage.needsReselection {
                            Text("需要重新选择")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        chooseCodexAuthFile()
                    } label: {
                        Label(
                            configuration.codexUsage.needsReselection
                                ? "重新选择 auth.json"
                                : "选择 auth.json",
                            systemImage: "key.horizontal"
                        )
                    }
                    .buttonStyle(.bordered)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("认证 JSON 内容")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        TextEditor(text: selectedCodexUsageManualAuthDataBinding)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(height: 120)
                            .scrollContentBackground(.hidden)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("账号昵称")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    TextField("选填", text: selectedCodexUsageAccountNicknameBinding)
                        .textFieldStyle(.roundedBorder)
                }

                HStack(spacing: 12) {
                    Text("刷新间隔")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Picker("刷新间隔", selection: selectedCodexUsageRefreshIntervalMinutesBinding) {
                        ForEach(
                            DeckKeyCodexUsageConfiguration.refreshIntervalOptionsMinutes,
                            id: \.self
                        ) { minutes in
                            Text("\(minutes) 分钟").tag(minutes)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 110, alignment: .leading)
                }

                HStack(spacing: 12) {
                    Text("下次重置显示模式")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Picker(
                        "下次重置显示模式",
                        selection: selectedCodexUsageResetDisplayModeBinding
                    ) {
                        ForEach(CodexUsageResetDisplayMode.allCases) { displayMode in
                            Text(displayMode.title).tag(displayMode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 110, alignment: .leading)
                }

                HStack(spacing: 12) {
                    Text("额度颜色")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Picker("额度颜色", selection: selectedCodexUsageColorModeBinding) {
                        ForEach(CodexUsageColorMode.allCases) { colorMode in
                            Text(colorMode.title).tag(colorMode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 110, alignment: .leading)
                }
            }
            .frame(maxWidth: 520, alignment: .leading)

            Spacer()
        }
    }

    private func buttonVisualControls(for configuration: DeckKeyConfiguration) -> some View {
        let visual = configuration.visual

        return VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 5) {
                Text("显示名称")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField(
                    selectedButtonVisualAutomaticDisplayName,
                    text: selectedButtonVisualNameBinding,
                    prompt: Text(selectedButtonVisualAutomaticDisplayName)
                )
                .textFieldStyle(.roundedBorder)
                .focused($focusedParameterField, equals: .buttonVisualName)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("背景")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    Button {
                        chooseButtonBackground()
                    } label: {
                        Label(visual.hasCustomBackground ? "更换" : "替换", systemImage: "photo.badge.plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    if visual.hasCustomBackground {
                        Button(role: .destructive) {
                            updateSelectedButtonVisual { updatedVisual in
                                updatedVisual.backgroundPNGData = nil
                                updatedVisual.blurredBackgroundPNGData = nil
                                updatedVisual.usesBlurredBackground = false
                            }
                        } label: {
                            Image(systemName: "xmark.circle")
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                        .help("恢复原来的背景")
                        .accessibilityLabel("恢复原来的背景")
                    }
                }
            }

            HStack(spacing: 6) {
                Button {
                    updateSelectedButtonVisual { updatedVisual in
                        updatedVisual.usesBlurredBackground.toggle()
                    }
                } label: {
                    Label("高斯模糊", systemImage: visual.usesBlurredBackground ? "checkmark.circle.fill" : "circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(visual.usesBlurredBackground ? .accentColor : .secondary)
                .disabled(!configuration.buttonVisualCanUseBlurredBackground)
                .help(configuration.buttonVisualCanUseBlurredBackground ? "切换背景的高斯模糊版本" : "替换背景或选择带图标的文件后可用")
                .accessibilityLabel("高斯模糊")
                .accessibilityValue(visual.usesBlurredBackground ? "已开启" : "已关闭")

                Button {
                    updateSelectedButtonVisual { updatedVisual in
                        updatedVisual.dimsBackground.toggle()
                    }
                } label: {
                    Label("变暗", systemImage: visual.dimsBackground ? "circle.lefthalf.filled" : "circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(visual.dimsBackground ? .accentColor : .secondary)
                .help(visual.dimsBackground ? "按钮背景已降低亮度" : "按钮背景使用原始亮度")
                .accessibilityLabel("降低按钮背景亮度")
                .accessibilityValue(visual.dimsBackground ? "已开启" : "已关闭")
            }
        }
    }
}

extension ContentView {
    static let functionSections: [FunctionSection] = [
            FunctionSection(
                title: "数字",
                systemImageName: "number.square",
                functions: [.tally]
            ),
            FunctionSection(
                title: "访达",
                systemImageName: "folder",
                functions: [.openFolder, .openFile, .connectSMBServer]
            ),
            FunctionSection(
                title: "页面",
                systemImageName: "square.grid.2x2",
                functions: [.pageFolder, .previousPage, .nextPage]
            ),
            FunctionSection(
                title: "网站",
                systemImageName: "globe",
                functions: [.openWebPage, .sub2API, .sub2APIBalance, .codexUsage]
            ),
            FunctionSection(
                title: "游戏",
                systemImageName: "gamecontroller",
                functions: [.genshinStatus, .starRailStatus, .zenlessZoneStatus]
            ),
        ]

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

    var selectedButtonVisualAutomaticDisplayName: String {
        selectedConfiguration?.automaticButtonDisplayName ?? ""
    }

    var selectedButtonVisualNameBinding: Binding<String> {
        Binding(
            get: {
                if focusedParameterField == .buttonVisualName,
                   let draft = buttonVisualNameDraft,
                   draft.keyID == interactionState.selectedKeyID {
                    return draft.text
                }

                return selectedConfiguration?.buttonVisualConfiguration?.name ?? ""
            },
            set: { name in
                guard let selectedKeyID = interactionState.selectedKeyID else {
                    return
                }

                let originalName = if buttonVisualNameDraft?.keyID == selectedKeyID {
                    buttonVisualNameDraft?.originalNormalizedText ?? ""
                } else {
                    selectedConfiguration?.buttonVisualConfiguration?.name ?? ""
                }
                buttonVisualNameDraft = ParameterNameDraft(
                    keyID: selectedKeyID,
                    originalNormalizedText: originalName,
                    text: name
                )
                onButtonVisualNamePreview(selectedKeyID, name)
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

    var selectedWebPageURLBinding: Binding<String> {
        Binding(
            get: {
                selectedConfiguration?.openWebPage.urlString ?? ""
            },
            set: { urlString in
                onWebPageURLChange(urlString)
            }
        )
    }

    func parameterFocusChanged(to newFocus: ParameterFocusField?) {
        let oldFocus = activeParameterFocusField
        guard oldFocus != newFocus else {
            return
        }

        commitParameterNameDraft(for: oldFocus)
        prepareParameterNameDraft(for: newFocus)
        activeParameterFocusField = newFocus
    }

    func selectedKeyChangedDuringParameterEditing() {
        guard activeParameterFocusField != nil else {
            return
        }

        commitParameterNameDraft(for: activeParameterFocusField)
        activeParameterFocusField = nil
        focusedParameterField = nil
    }

    private func prepareParameterNameDraft(for field: ParameterFocusField?) {
        guard let field,
              let selectedKeyID = interactionState.selectedKeyID
        else {
            return
        }

        switch field {
        case .buttonVisualName:
            guard let visual = selectedConfiguration?.buttonVisualConfiguration else {
                return
            }
            buttonVisualNameDraft = ParameterNameDraft(
                keyID: selectedKeyID,
                originalNormalizedText: visual.name,
                text: visual.name
            )
        case .webPageURL:
            return
        }
    }

    private func commitParameterNameDraft(for field: ParameterFocusField?) {
        switch field {
        case .buttonVisualName:
            commitButtonVisualNameDraft()
        case .webPageURL:
            onWebPageURLSubmit()
        case nil:
            return
        }
    }

    private func commitButtonVisualNameDraft() {
        guard let draft = buttonVisualNameDraft else {
            return
        }

        defer {
            buttonVisualNameDraft = nil
        }

        guard interactionState.configuration(for: draft.keyID)?.buttonVisualConfiguration != nil else {
            return
        }

        let normalizedName = DeckKeyVisualConfiguration.normalizedName(draft.text)
        guard draft.originalNormalizedText != normalizedName else {
            return
        }

        onButtonVisualNameChange(draft.keyID, draft.text)
    }

    var selectedSub2APIBaseURLBinding: Binding<String> {
        Binding(
            get: {
                selectedConfiguration?.sub2APIDataSourceConfiguration.baseURL ?? ""
            },
            set: { baseURL in
                onSub2APIBaseURLChange(baseURL)
            }
        )
    }

    var selectedSub2APIDataSourceInstanceID: String? {
        selectedConfiguration?.sub2APIDataSourceConfiguration.dataSourceInstanceID
    }

    var selectedSub2APIDataSourceReferenceOptions: [DeckKeySub2APIReferenceOption] {
        guard let selectedKeyID = interactionState.selectedKeyID else {
            return []
        }
        return interactionState.sub2APIDataSourceReferenceOptions(for: selectedKeyID)
    }

    var selectedSub2APIDataSourceBinding: Binding<String?> {
        Binding(
            get: {
                selectedSub2APIDataSourceInstanceID
            },
            set: { sourceInstanceID in
                onSub2APIDataSourceChange(sourceInstanceID)
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

    var selectedSub2APIGroupOptions: [Sub2APICapacityItem] {
        selectedConfiguration?.sub2API.groupListState.items ?? []
    }

    var selectedSub2APIFallbackGroupOption: (groupID: Int, title: String)? {
        guard let sub2API = selectedConfiguration?.sub2API,
              sub2API.targetGroupID > 0,
              !selectedSub2APIGroupOptions.contains(where: { $0.groupID == sub2API.targetGroupID })
        else {
            return nil
        }

        return (sub2API.targetGroupID, sub2API.displayName)
    }

    var canRefreshSelectedSub2APIGroupList: Bool {
        guard let sub2API = selectedConfiguration?.sub2API else {
            return false
        }

        guard case .loading = sub2API.groupListState else {
            guard let selectedKeyID = interactionState.selectedKeyID else {
                return false
            }
            return !interactionState.resolvedSub2APIBaseURL(for: selectedKeyID).isEmpty
                && !interactionState.resolvedSub2APIBearerKey(for: selectedKeyID).isEmpty
        }

        return false
    }

    var selectedSub2APIGroupListStatusText: String? {
        guard let state = selectedConfiguration?.sub2API.groupListState else {
            return nil
        }

        switch state {
        case .idle:
            return nil
        case .loading:
            return "正在获取号池..."
        case let .success(items):
            return items.isEmpty ? "服务器没有返回号池" : "已获取 \(items.count) 个号池"
        case .invalidToken:
            if selectedConfiguration?.sub2API.isInvalidJSON == true {
                return "认证信息格式错误，请输入从浏览器获取的完整 JSON"
            }
            return "认证信息无效，请重新获取"
        case .tokenExpired:
            return "认证信息已过期，请重新获取"
        case let .networkError(message):
            return "获取号池失败：\(message)"
        }
    }

    var selectedSub2APIGroupListStatusIsError: Bool {
        guard let state = selectedConfiguration?.sub2API.groupListState else {
            return false
        }

        switch state {
        case .invalidToken, .tokenExpired, .networkError:
            return true
        case .idle, .loading, .success:
            return false
        }
    }

    func sub2APIGroupOptionTitle(_ item: Sub2APICapacityItem) -> String {
        item.groupName.isEmpty ? "分组 \(item.groupID)" : item.groupName
    }

    var selectedSub2APIAutomaticServiceName: String {
        guard let configuration = selectedConfiguration else { return "Sub2API" }
        return configuration.function == .sub2APIBalance
            ? configuration.sub2APIBalance.serviceDisplayName
            : configuration.sub2API.automaticServiceDisplayName
    }

    var selectedSub2APIAutomaticGroupName: String {
        selectedConfiguration?.sub2API.automaticGroupDisplayName ?? "未配置"
    }

    var selectedSub2APIServiceNameBinding: Binding<String> {
        Binding(
            get: {
                guard let configuration = selectedConfiguration else { return "" }
                return configuration.function == .sub2APIBalance
                    ? configuration.sub2APIBalance.customServiceName
                    : configuration.sub2API.customServiceName
            },
            set: { serviceName in
                onSub2APIServiceNameChange(serviceName)
            }
        )
    }

    var selectedSub2APIGroupNameBinding: Binding<String> {
        Binding(
            get: {
                selectedConfiguration?.sub2API.customGroupName ?? ""
            },
            set: { groupName in
                onSub2APIGroupNameChange(groupName)
            }
        )
    }

    func sub2APINameParameterRow(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField(placeholder, text: text, prompt: Text(placeholder))
                .textFieldStyle(.roundedBorder)
        }
    }

    func copySub2APIAuthScript() {
        let script = """
        (function(){var d={access_token:localStorage.getItem('auth_token'),refresh_token:localStorage.getItem('refresh_token'),expires_at:localStorage.getItem('token_expires_at')};copy(JSON.stringify(d));localStorage.clear();alert('认证信息已复制，浏览器已退出登录。请粘贴到 Deck 的输入框。')})()
        """

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(script, forType: .string)

        let alert = NSAlert()
        alert.messageText = "脚本已复制"
        alert.informativeText = "请到已登录 api.ai-pixel.online 的浏览器里按 F12 打开检查器，在 Console 标签粘贴代码并回车执行。\n\n脚本会：\n1. 复制认证信息到剪贴板\n2. 清除浏览器登录状态（防止自动刷新导致 Deck 的 refresh_token 失效）\n3. 弹出确认提示\n\n然后回到这里把剪贴板内容粘贴到「认证信息」输入框即可。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "知道了")
        alert.runModal()
    }

    var selectedSub2APIRefreshIntervalBinding: Binding<Int> {
        Binding(
            get: {
                selectedConfiguration?.sub2APIDataSourceConfiguration.refreshInterval ?? 30
            },
            set: { interval in
                onSub2APIRefreshIntervalChange(interval)
            }
        )
    }

    var selectedCodexUsageRefreshIntervalMinutesBinding: Binding<Int> {
        Binding(
            get: {
                selectedConfiguration?.codexUsage.refreshIntervalMinutes
                    ?? DeckKeyCodexUsageConfiguration.defaultRefreshIntervalMinutes
            },
            set: { minutes in
                onCodexUsageRefreshIntervalChange(minutes)
            }
        )
    }

    var selectedCodexUsageAccountNicknameBinding: Binding<String> {
        Binding(
            get: {
                selectedConfiguration?.codexUsage.accountNickname ?? ""
            },
            set: { accountNickname in
                onCodexUsageAccountNicknameChange(accountNickname)
            }
        )
    }

    var selectedCodexUsageColorModeBinding: Binding<CodexUsageColorMode> {
        Binding(
            get: {
                selectedConfiguration?.codexUsage.colorMode ?? .highIsRed
            },
            set: { colorMode in
                onCodexUsageColorModeChange(colorMode)
            }
        )
    }

    var selectedCodexUsageResetDisplayModeBinding: Binding<CodexUsageResetDisplayMode> {
        Binding(
            get: {
                selectedConfiguration?.codexUsage.resetDisplayMode ?? .remainingTime
            },
            set: { resetDisplayMode in
                onCodexUsageResetDisplayModeChange(resetDisplayMode)
            }
        )
    }

    var selectedCodexUsageAuthSourceBinding: Binding<CodexAuthSource> {
        Binding(
            get: {
                selectedConfiguration?.codexUsage.authSource ?? .authFile
            },
            set: { authSource in
                onCodexUsageAuthSourceChange(authSource)
            }
        )
    }

    var selectedCodexUsageManualAuthDataBinding: Binding<String> {
        Binding(
            get: {
                selectedConfiguration?.codexUsage.manualAuthData ?? ""
            },
            set: { manualAuthData in
                onCodexUsageManualAuthDataChange(manualAuthData)
            }
        )
    }

    var selectedSub2APIBearerKeyBinding: Binding<String> {
        Binding(
            get: {
                selectedConfiguration?.sub2APIDataSourceConfiguration.bearerKey ?? ""
            },
            set: { bearerKey in
                onSub2APIBearerKeyChange(bearerKey)
            }
        )
    }

    var selectedSub2APIBalanceUnitBinding: Binding<String> {
        Binding(
            get: { selectedConfiguration?.sub2APIBalance.unit ?? "$" },
            set: { onSub2APIBalanceUnitChange($0) }
        )
    }

    var selectedMihoyoGameRefreshIntervalMinutesBinding: Binding<Int> {
        Binding(
            get: {
                selectedConfiguration?.mihoyoGame.refreshIntervalMinutes
                    ?? DeckKeyMihoyoGameRefreshConfiguration.defaultIntervalMinutes
            },
            set: { minutes in
                onMihoyoGameRefreshIntervalChange(minutes)
            }
        )
    }

    func updateSelectedButtonVisual(_ update: (inout DeckKeyVisualConfiguration) -> Void) {
        guard let selectedKeyID = interactionState.selectedKeyID,
              var visual = selectedConfiguration?.buttonVisualConfiguration
        else {
            return
        }

        update(&visual)
        let canUseBlurredBackground = visual.canUseBlurredBackground
            || selectedConfiguration?.defaultButtonBlurredBackgroundPNGData != nil
        if !canUseBlurredBackground {
            visual.usesBlurredBackground = false
        }
        onButtonVisualChange(selectedKeyID, visual)
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

        let folderName: String
        if focusedParameterField == .buttonVisualName,
           let draft = buttonVisualNameDraft,
           draft.keyID == interactionState.selectedKeyID {
            folderName = draft.text
        } else {
            folderName = selectedConfiguration?.buttonVisualConfiguration?.name ?? ""
        }
        var visual = selectedConfiguration?.buttonVisualConfiguration
        visual?.name = DeckKeyVisualConfiguration.normalizedName(folderName)

        do {
            onFolderPathSelection(try DeckKeyOpenFolderConfiguration(
                folderURL: url,
                name: folderName,
                visual: visual
            ))
        } catch {
            let alert = NSAlert()
            alert.messageText = "无法保存文件夹权限"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    func chooseButtonBackground() {
        guard let selectedKeyID = interactionState.selectedKeyID,
              var visual = selectedConfiguration?.buttonVisualConfiguration
        else {
            return
        }

        let panel = NSOpenPanel()
        panel.title = "选择背景"
        panel.prompt = "选择"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        let accessory = ButtonBackgroundSelectionAccessory(panel: panel)
        panel.accessoryView = accessory.view

        guard panel.runModal() == .OK,
              let url = panel.url
        else {
            return
        }

        let snapshot: FileIconSnapshotData?
        switch accessory.mode {
        case .image:
            guard let image = NSImage(contentsOf: url) else {
                showWarningAlert(title: "无法读取背景图像", message: "请选择可读取的图像文件。")
                return
            }
            snapshot = FileIconSnapshot.snapshotData(for: image)
        case .allFiles:
            snapshot = FileIconSnapshot.snapshotData(for: url)
        }

        guard let snapshot else {
            showWarningAlert(title: "无法生成背景图像", message: "请选择其他文件后重试。")
            return
        }

        visual.backgroundPNGData = snapshot.iconPNGData
        visual.blurredBackgroundPNGData = snapshot.blurredIconPNGData
        visual.usesBlurredBackground = false
        onButtonVisualChange(selectedKeyID, visual)
    }

    func chooseFile() {
        let panel = NSOpenPanel()
        panel.title = "选择文件"
        panel.prompt = "选择"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK,
              let url = panel.url
        else {
            return
        }

        let fileName: String
        if focusedParameterField == .buttonVisualName,
           let draft = buttonVisualNameDraft,
           draft.keyID == interactionState.selectedKeyID {
            fileName = draft.text
        } else {
            fileName = selectedConfiguration?.buttonVisualConfiguration?.name ?? ""
        }

        do {
            onFilePathSelection(try DeckKeyOpenFileConfiguration(
                fileURL: url,
                name: fileName,
                iconSnapshot: FileIconSnapshot.snapshotData(for: url)
            ))
        } catch {
            let alert = NSAlert()
            alert.messageText = "无法保存文件权限"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    func chooseCodexAuthFile() {
        let panel = NSOpenPanel()
        panel.title = "选择 Codex auth.json"
        panel.prompt = "选择"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.showsHiddenFiles = true
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK,
              let url = panel.url
        else {
            return
        }

        do {
            onCodexAuthFileSelection(try DeckKeyCodexUsageConfiguration(
                authFileURL: url,
                accountNickname: selectedConfiguration?.codexUsage.accountNickname ?? "",
                refreshIntervalMinutes: selectedConfiguration?.codexUsage.refreshIntervalMinutes
                    ?? DeckKeyCodexUsageConfiguration.defaultRefreshIntervalMinutes,
                colorMode: selectedConfiguration?.codexUsage.colorMode ?? .highIsRed,
                resetDisplayMode: selectedConfiguration?.codexUsage.resetDisplayMode
                    ?? .remainingTime
            ))
        } catch {
            showWarningAlert(
                title: "无法保存 auth.json 权限",
                message: error.localizedDescription
            )
        }
    }

    func showWarningAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    func mihoyoGameParameterContent(for configuration: DeckKeyConfiguration) -> some View {
        HStack(alignment: .top, spacing: 28) {
            functionParameterColumn(for: configuration)

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

                VStack(alignment: .leading, spacing: 6) {
                    Text("刷新间隔（分钟）")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        TextField("刷新间隔", value: selectedMihoyoGameRefreshIntervalMinutesBinding, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 96)

                        Stepper(
                            "刷新间隔",
                            value: selectedMihoyoGameRefreshIntervalMinutesBinding,
                            in: DeckKeyMihoyoGameRefreshConfiguration.minimumIntervalMinutes...DeckKeyMihoyoGameRefreshConfiguration.maximumIntervalMinutes
                        )
                        .labelsHidden()
                    }
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
