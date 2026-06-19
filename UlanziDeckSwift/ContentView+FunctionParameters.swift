import AppKit
import SwiftUI

extension ContentView {
    @ViewBuilder
    func parameterContent(for configuration: DeckKeyConfiguration) -> some View {
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

                    VStack(alignment: .leading, spacing: 4) {
                        Text(configuration.openFolder.path ?? "未选择文件夹")
                            .font(.callout)
                            .foregroundStyle(configuration.openFolder.path == nil ? Color.secondary : Color.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if configuration.openFolder.needsReselection {
                            Text("需要重新选择")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Button {
                    chooseFolder()
                } label: {
                    Label(
                        configuration.openFolder.needsReselection ? "重新选择文件夹" : "选择文件夹",
                        systemImage: "folder.badge.plus"
                    )
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

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("显示名称")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        TextField("NAS", text: selectedSMBServerNameBinding)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 260, alignment: .leading)
                    }

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

                        Text("名称会显示在按钮画面中心；地址只填写服务器和共享名，例如 server.local/share。连接时会使用系统认证窗口。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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

                        TextField("Bearer Key", text: selectedSub2APIBearerKeyBinding)
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

    var selectedSMBServerNameBinding: Binding<String> {
        Binding(
            get: {
                selectedConfiguration?.smbServer.name ?? ""
            },
            set: { name in
                onSMBServerNameChange(name)
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

        do {
            onFolderPathSelection(try DeckKeyOpenFolderConfiguration(folderURL: url))
        } catch {
            let alert = NSAlert()
            alert.messageText = "无法保存文件夹权限"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
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
