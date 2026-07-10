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
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Base URL")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        TextField("your-api.example.com", text: selectedSub2APIBaseURLBinding)
                            .textFieldStyle(.roundedBorder)
                    }

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

                        SecureField("Bearer Key", text: selectedSub2APIBearerKeyBinding)
                            .textFieldStyle(.roundedBorder)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
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
                functions: [.openWebPage, .sub2API]
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
            return !sub2API.baseURL.isEmpty && !sub2API.bearerKey.isEmpty
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
            return "Bearer Key 无效"
        case .tokenExpired:
            return "Bearer Key 已过期"
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
        selectedConfiguration?.sub2API.automaticServiceDisplayName ?? "Sub2API"
    }

    var selectedSub2APIAutomaticGroupName: String {
        selectedConfiguration?.sub2API.automaticGroupDisplayName ?? "未配置"
    }

    var selectedSub2APIServiceNameBinding: Binding<String> {
        Binding(
            get: {
                selectedConfiguration?.sub2API.customServiceName ?? ""
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

    private func showWarningAlert(title: String, message: String) {
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
