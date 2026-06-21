import AppKit
import Foundation
import Darwin
import Testing
@testable import UlanziDeckSwift

@Suite(.serialized)
struct UlanziDeckSwiftTests {
    @Test func h200PrototypeLayoutContainsFourteenNumberedKeys() {
        let layout = DeckGridLayout.h200Prototype

        #expect(layout.keys.map(\.id) == Array(1...14))
        #expect(layout.rows.map(\.count) == [5, 5, 4])
        #expect(layout.columnCount == 5)
        #expect(layout.keys.last?.columnSpan == 2)
        #expect(layout.keyID(forSequentialInputIndex: 0) == 1)
        #expect(layout.keyID(forSequentialInputIndex: 13) == 14)
        #expect(layout.keyID(forSequentialInputIndex: 14) == nil)
    }

    @Test func fileSingleInstanceLockerRejectsDuplicateBundleIdentifier() throws {
        let lockDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("UlanziDeckSwiftTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: lockDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: lockDirectory)
        }

        let secondLocker = FileSingleInstanceLocker(lockDirectory: lockDirectory)

        do {
            let firstLocker = FileSingleInstanceLocker(lockDirectory: lockDirectory)

            #expect(firstLocker.tryAcquire(identifier: "com.iBobby.UlanziDeckSwift"))
            #expect(!secondLocker.tryAcquire(identifier: "com.iBobby.UlanziDeckSwift"))
        }

        #expect(secondLocker.tryAcquire(identifier: "com.iBobby.UlanziDeckSwift"))
    }

    @Test func singleInstanceGuardReportsExistingApplicationWhenLockIsBusy() {
        let existingApplication = ExistingApplication(
            processIdentifier: 1234,
            bundleURL: URL(filePath: "/Applications/Ulanzi Deck.app")
        )
        let locker = FakeSingleInstanceLocker(results: [false])
        let locator = FakeExistingApplicationLocator(results: [existingApplication])
        let guardInstance = SingleInstanceGuard(
            bundleIdentifier: "com.iBobby.UlanziDeckSwift",
            locker: locker,
            locator: locator
        )

        #expect(guardInstance.acquire() == .blockedByExistingApplication(existingApplication))
        #expect(locker.requestedIdentifiers == ["com.iBobby.UlanziDeckSwift"])
        #expect(locator.lookupRequests == [
            FakeExistingApplicationLocator.LookupRequest(
                bundleIdentifier: "com.iBobby.UlanziDeckSwift",
                latestLaunchDate: nil
            )
        ])
    }

    @Test func singleInstanceGuardRejectsWhenOlderApplicationAlreadyExists() {
        let existingApplication = ExistingApplication(
            processIdentifier: 5678,
            bundleURL: URL(filePath: "/Users/ibobby/Desktop/Ulanzi Deck.app")
        )
        let locker = FakeSingleInstanceLocker(results: [true])
        let locator = FakeExistingApplicationLocator(results: [existingApplication])
        let launchDate = Date(timeIntervalSince1970: 100)
        let guardInstance = SingleInstanceGuard(
            bundleIdentifier: "com.iBobby.UlanziDeckSwift",
            locker: locker,
            locator: locator,
            currentLaunchDate: launchDate,
            existingApplicationGraceInterval: 2
        )

        #expect(guardInstance.acquire() == .blockedByExistingApplication(existingApplication))
        #expect(locker.requestedIdentifiers == ["com.iBobby.UlanziDeckSwift"])
        #expect(locator.lookupRequests == [
            FakeExistingApplicationLocator.LookupRequest(
                bundleIdentifier: "com.iBobby.UlanziDeckSwift",
                latestLaunchDate: launchDate.addingTimeInterval(-2)
            )
        ])
    }

    @Test func singleInstanceGuardAllowsLaunchWhenNoExistingApplicationIsFound() {
        let locker = FakeSingleInstanceLocker(results: [true])
        let locator = FakeExistingApplicationLocator(results: [nil])
        let guardInstance = SingleInstanceGuard(
            bundleIdentifier: "com.iBobby.UlanziDeckSwift",
            locker: locker,
            locator: locator,
            currentLaunchDate: Date(timeIntervalSince1970: 100),
            existingApplicationGraceInterval: 2
        )

        #expect(guardInstance.acquire() == .acquired)
        #expect(locker.requestedIdentifiers == ["com.iBobby.UlanziDeckSwift"])
    }

    @Test func singleInstanceGuardReportsUnknownBlockerWhenLockIsBusyWithoutVisibleApplication() {
        let locker = FakeSingleInstanceLocker(results: [false])
        let locator = FakeExistingApplicationLocator(results: [nil])
        let guardInstance = SingleInstanceGuard(
            bundleIdentifier: "com.iBobby.UlanziDeckSwift",
            locker: locker,
            locator: locator
        )

        #expect(guardInstance.acquire() == .blockedByUnknownApplication)
        #expect(locker.requestedIdentifiers == ["com.iBobby.UlanziDeckSwift"])
        #expect(locator.lookupRequests == [
            FakeExistingApplicationLocator.LookupRequest(
                bundleIdentifier: "com.iBobby.UlanziDeckSwift",
                latestLaunchDate: nil
            )
        ])
    }

    @Test func appSkipsSingleInstanceGuardDuringTests() {
        #expect(UlanziDeckSwiftApp.isRunningTests)
    }

    @Test func previewGridMetricsKeepsWideKeyRowAligned() {
        let layout = DeckGridLayout.h200Prototype
        let metrics = DeckPreviewGridMetrics.h200
        let layoutMetrics = DeckPreviewLayoutMetrics.h200

        #expect(metrics.slotWidth(columnSpan: 1) == 82)
        #expect(metrics.slotWidth(columnSpan: 2) == 180)
        #expect(layout.rows.map { metrics.rowWidth(for: $0) } == [474, 474, 474])
        #expect(metrics.gridHeight(rowCount: layout.rows.count) == 278)
        #expect(layoutMetrics.gridContentWidth(for: layout) == 474)
        #expect(layoutMetrics.gridContentHeight(for: layout) == 278)
        #expect(layoutMetrics.deckSurfaceWidth(for: layout) == 530)
        #expect(layoutMetrics.deckSurfaceHeight(for: layout) == 334)
        #expect(layoutMetrics.previewAreaMinimumWidth(for: layout) == 586)
        #expect(layoutMetrics.previewAreaHeight(for: layout) == 404)
    }

    @Test func shortPressingAKeyDoesNotChangeUISelectionAndIncrementsTally() {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)

        state.triggerShortPress(keyID: 7)
        state.triggerShortPress(keyID: 7)
        state.triggerShortPress(keyID: 14)

        #expect(state.selectedKeyID == 1)
        #expect(state.tallyValue(for: 7) == 2)
        #expect(state.tallyValue(for: 14) == 1)
    }

    @Test func displayModelUsesTheSameTextAsTheStartupPackage() {
        let layout = DeckGridLayout.h200Prototype
        let state = DeckGridInteractionState(layout: layout)
        let displays = state.displays(for: layout)

        #expect(displays.map(\.title) == Array(repeating: "0", count: 14))
        #expect(displays.allSatisfy { $0.subtitle == "默认 0" })
        #expect(displays.first?.isSelected == true)
        #expect(displays.last?.isWide == true)
        #expect(displays.last?.devicePixelSize == H200DeviceTarget.smallWindowIconSize)
    }

    @Test func squareKeySwapExchangesConfigurationsWithoutReorderingLayout() {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)
        let rowsBefore = layout.rows

        state.assign(.openFolder, to: 1)
        state.setFolderConfiguration(Self.folderConfiguration(path: "/Users/ibobby/Documents"), for: 1)
        state.assign(.connectSMBServer, to: 2)
        state.setSMBServerAddress("nas.local/media", for: 2)
        state.setSMBServerName("NAS", for: 2)
        state.select(keyID: 1)

        let didSwap = state.swapSquareConfigurations(sourceKeyID: 1, targetKeyID: 2)
        let didRejectWideKey = state.swapSquareConfigurations(sourceKeyID: 1, targetKeyID: 14)
        let didRejectSameKey = state.swapSquareConfigurations(sourceKeyID: 1, targetKeyID: 1)

        #expect(didSwap)
        #expect(layout.rows == rowsBefore)
        #expect(state.selectedKeyID == 2)
        #expect(state.configuration(for: 1)?.function == .connectSMBServer)
        #expect(state.configuration(for: 1)?.smbServer.address == "nas.local/media")
        #expect(state.configuration(for: 1)?.buttonVisualConfiguration?.name == "NAS")
        #expect(state.configuration(for: 2)?.function == .openFolder)
        #expect(state.configuration(for: 2)?.openFolder.path == "/Users/ibobby/Documents")
        #expect(!didRejectWideKey)
        #expect(!didRejectSameKey)
    }

    @Test func pageFolderCreatesNestedPageWithBackKeyAndDepthLimit() throws {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)

        #expect(state.canAssignPageFolder(to: 2))
        let didAssignRootPageFolder = state.assign(.pageFolder, to: 2)
        #expect(didAssignRootPageFolder)
        let firstPageID = try #require(state.pageID(for: 2))
        let rootDisplay = state.display(for: layout.keys[1])
        #expect(rootDisplay.pageFolderButtonContent?.displayName == "文件夹")
        #expect(rootDisplay.title == "文件夹")

        let didEnterFirstPage = state.enterPageFolder(keyID: 2)
        #expect(didEnterFirstPage)
        #expect(state.currentPageID == firstPageID)
        #expect(state.currentPageDepth == 1)
        #expect(state.navigationPathTitles == ["主页", "文件夹"])
        #expect(state.configuration(for: 1)?.function == .pageBack)
        #expect(state.configurations.filter { $0.key != 1 }.values.allSatisfy { $0.function == DeckKeyFunction.none })

        let didAssignSecondLevelPageFolder = state.assign(.pageFolder, to: 2)
        #expect(didAssignSecondLevelPageFolder)
        let didEnterSecondPage = state.enterPageFolder(keyID: 2)
        #expect(didEnterSecondPage)
        #expect(state.currentPageDepth == 2)

        let didAssignThirdLevelPageFolder = state.assign(.pageFolder, to: 3)
        #expect(didAssignThirdLevelPageFolder)
        let didEnterThirdPage = state.enterPageFolder(keyID: 3)
        #expect(didEnterThirdPage)
        #expect(state.currentPageDepth == 3)
        #expect(!state.canAssignPageFolder(to: 4))
        let didRejectFourthLevelPageFolder = state.assign(.pageFolder, to: 4)
        #expect(!didRejectFourthLevelPageFolder)
    }

    @Test func pageBackCannotBeDeletedOrReassignedButCanMoveWithinSquareKeys() {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)

        state.assign(.pageFolder, to: 2)
        state.enterPageFolder(keyID: 2)

        #expect(state.configuration(for: 1)?.function == .pageBack)
        #expect(!state.canDeleteFunction(keyID: 1))
        let didClearBackKey = state.clearFunction(keyID: 1)
        #expect(!didClearBackKey)
        let didReassignBackKey = state.assign(.tally, to: 1)
        #expect(!didReassignBackKey)

        let didSwapBackKey = state.swapSquareConfigurations(sourceKeyID: 1, targetKeyID: 3)
        #expect(didSwapBackKey)
        #expect(state.configuration(for: 1)?.function == DeckKeyFunction.none)
        #expect(state.configuration(for: 3)?.function == .pageBack)
        let didClearMovedBackKey = state.clearFunction(keyID: 3)
        #expect(!didClearMovedBackKey)
        let didGoBack = state.goBackPage()
        #expect(didGoBack)
        #expect(state.currentPageID == DeckGridInteractionState.rootPageID)
    }

    @Test func clearingPageFolderDeletesNestedPageSubtree() throws {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)

        state.assign(.pageFolder, to: 2)
        let firstPageID = try #require(state.pageID(for: 2))
        state.enterPageFolder(keyID: 2)
        state.assign(.pageFolder, to: 3)
        let secondPageID = try #require(state.pageID(for: 3))
        state.goToRootPage()

        #expect(state.persistedPages.map(\.id).contains(firstPageID))
        #expect(state.persistedPages.map(\.id).contains(secondPageID))
        let didClearPageFolder = state.clearFunction(keyID: 2)
        #expect(didClearPageFolder)
        #expect(!state.persistedPages.map(\.id).contains(firstPageID))
        #expect(!state.persistedPages.map(\.id).contains(secondPageID))
        let didEnterClearedPageFolder = state.enterPageFolder(keyID: 2)
        #expect(!didEnterClearedPageFolder)
    }

    @Test func wideKeyDisplayModeChangesPreviewAndDisablesFunctionPresses() {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)

        let didRejectNormalKey = state.setDisplayMode(.clock, for: 1)
        let didSetClock = state.setDisplayMode(.clock, for: 14)
        let didBeginPress = state.beginPress(keyID: 14)
        let didTriggerShortPress = state.triggerShortPress(keyID: 14)
        let display = state.display(for: layout.keys[13])

        #expect(!didRejectNormalKey)
        #expect(didSetClock)
        #expect(!didBeginPress)
        #expect(!didTriggerShortPress)
        #expect(state.tallyValue(for: 14) == 0)
        #expect(state.configuration(for: 14)?.function == DeckKeyFunction.none)
        #expect(state.configuration(for: 14)?.displayMode == .clock)
        #expect(display.title == "时钟")
        #expect(display.subtitle == "模拟表盘")

        state.assign(.sub2API, to: 14)

        #expect(state.configuration(for: 14)?.displayMode == .function)
        #expect(state.display(for: layout.keys[13]).title == "号池")
    }

    @Test func uiSelectionDoesNotChangeDisplayRenderIdentity() {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)
        let initiallySelectedIdentity = state.display(for: layout.keys[0]).renderIdentity

        state.select(keyID: 2)
        let unselectedIdentity = state.display(for: layout.keys[0]).renderIdentity
        state.triggerShortPress(keyID: 1)
        let updatedContentIdentity = state.display(for: layout.keys[0]).renderIdentity

        #expect(initiallySelectedIdentity == unselectedIdentity)
        #expect(initiallySelectedIdentity != updatedContentIdentity)
    }

    @Test func configuredSub2APIWithoutLoadedResultStillDisplaysUnconfiguredState() {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)

        state.assign(.sub2API, to: 3)
        state.setSub2APIBaseURL("api.example.com", for: 3)
        state.setSub2APIBearerKey("token", for: 3)
        state.setSub2APITargetGroupID(1215, for: 3)
        let display = state.display(for: layout.keys[2])

        #expect(display.title == "号池")
        #expect(display.subtitle == "未配置")
    }

    @Test func sub2APISuccessDisplayUsesServiceGroupAndAvailableConcurrency() throws {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)

        state.assign(.sub2API, to: 3)
        state.setSub2APIBaseURL("https://api.example.com/v1", for: 3)
        state.setSub2APITargetGroupID(1215, for: 3)
        state.setSub2APILastResult(.success(item: Self.sub2APICapacityItem(
            groupID: 1215,
            groupName: "PLUS共享号池",
            availableConcurrency: 3078
        )), for: 3)

        let display = state.display(for: layout.keys[2])
        let content = try #require(display.sub2APIButtonContent)

        #expect(display.title == "3078")
        #expect(display.subtitle == "api.example.com PLUS共享号池")
        #expect(content.serviceName == "api.example.com")
        #expect(content.groupName == "PLUS共享号池")
        #expect(content.availableConcurrency == 3078)
        #expect(content.availabilityLevel == .healthy)
    }

    @Test func sub2APICustomNamesOverrideAutomaticValuesAndPersist() throws {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)

        state.assign(.sub2API, to: 3)
        state.setSub2APIBaseURL("https://api.example.com/v1", for: 3)
        state.setSub2APITargetGroupID(1215, for: 3)
        state.setSub2APIServiceName(" 主站 ", for: 3)
        state.setSub2APIGroupName(" PLUS ", for: 3)
        state.setSub2APILastResult(.success(item: Self.sub2APICapacityItem(
            groupID: 1215,
            groupName: "PLUS共享号池",
            availableConcurrency: 49
        )), for: 3)

        var display = state.display(for: layout.keys[2])
        var content = try #require(display.sub2APIButtonContent)
        #expect(content.serviceName == "主站")
        #expect(content.groupName == "PLUS")
        #expect(content.availableConcurrency == 49)
        #expect(content.availabilityLevel == .critical)

        let configuration = try #require(state.configuration(for: 3))
        let data = try JSONEncoder().encode(configuration)
        let restored = try JSONDecoder().decode(DeckKeyConfiguration.self, from: data)
        #expect(restored.sub2API.customServiceName == "主站")
        #expect(restored.sub2API.customGroupName == "PLUS")
        #expect(restored.sub2API.lastResult == nil)
        #expect(restored.sub2API.groupListState == .idle)

        state.setSub2APIServiceName("", for: 3)
        state.setSub2APIGroupName("", for: 3)
        display = state.display(for: layout.keys[2])
        content = try #require(display.sub2APIButtonContent)
        #expect(content.serviceName == "api.example.com")
        #expect(content.groupName == "PLUS共享号池")
    }

    @Test func sub2APIBaseURLNormalizationBuildsCapacitySummaryURL() throws {
        let hostOnly = try Sub2APIBaseURL("api.example.com")
        let schemeQualified = try Sub2APIBaseURL("https://api.example.com")
        let pathPrefixed = try Sub2APIBaseURL("https://api.example.com/base/")
        let hostPathPrefixed = try Sub2APIBaseURL("api.example.com/base/")

        #expect(hostOnly.host == "api.example.com")
        #expect(hostOnly.capacitySummaryURL.absoluteString == "https://api.example.com/api/v1/channel-monitors/capacity-summary")
        #expect(schemeQualified.capacitySummaryURL.absoluteString == "https://api.example.com/api/v1/channel-monitors/capacity-summary")
        #expect(pathPrefixed.capacitySummaryURL.absoluteString == "https://api.example.com/base/api/v1/channel-monitors/capacity-summary")
        #expect(hostPathPrefixed.capacitySummaryURL.absoluteString == "https://api.example.com/base/api/v1/channel-monitors/capacity-summary")
    }

    @Test func sub2APIBaseURLNormalizationRejectsUnsupportedURLs() {
        for value in ["", "http://api.example.com", "https://api.example.com?debug=1", "https:///missing-host"] {
            var didThrow = false
            do {
                _ = try Sub2APIBaseURL(value)
            } catch {
                didThrow = true
                #expect(error is Sub2APIBaseURLError)
            }

            #expect(didThrow)
        }
    }

    @Test func sub2APIAvailabilityLevelUsesRequestedThresholds() {
        #expect(Sub2APIAvailabilityLevel(availableConcurrency: 500) == .healthy)
        #expect(Sub2APIAvailabilityLevel(availableConcurrency: 499) == .warning)
        #expect(Sub2APIAvailabilityLevel(availableConcurrency: 50) == .warning)
        #expect(Sub2APIAvailabilityLevel(availableConcurrency: 49) == .critical)
    }

    @Test func clearingFunctionMakesKeyEmptyAndInactive() {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)

        let didClear = state.clearFunction(keyID: 7)
        let didBeginPress = state.beginPress(keyID: 7)
        let didTriggerShortPress = state.triggerShortPress(keyID: 7)
        let didReset = state.resetTally(keyID: 7)

        let display = state.display(for: layout.keys[6])
        #expect(didClear)
        #expect(!didBeginPress)
        #expect(!didTriggerShortPress)
        #expect(!didReset)
        #expect(state.selectedKeyID == 7)
        #expect(state.configuration(for: 7)?.function == DeckKeyFunction.none)
        #expect(state.tallyValue(for: 7) == 0)
        #expect(state.pressedKeyIDs.isEmpty)
        #expect(display.title.isEmpty)
        #expect(display.subtitle.isEmpty)
    }

    @Test func unknownKeyDoesNotChangeTallyState() {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)

        state.triggerShortPress(keyID: 99)

        #expect(state.selectedKeyID == 1)
        #expect(state.configurations.values.allSatisfy { $0.tally.value == 0 })
        #expect(state.pressedKeyIDs.isEmpty)
    }

    @Test func tallyDefaultValueIsAlsoTheResetTarget() {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)

        state.setTallyDefaultValue(12, for: 4)
        state.triggerShortPress(keyID: 4)
        state.resetTally(keyID: 4)

        #expect(state.selectedKeyID == 4)
        #expect(state.tallyDefaultValue(for: 4) == 12)
        #expect(state.tallyValue(for: 4) == 12)
    }

    @Test func openFolderFunctionDisplaysSelectedFolderName() {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)
        let backgroundPNGData = Self.solidColorIconPNGData(color: NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 1))

        state.assign(.openFolder, to: 5)
        state.setFolderConfiguration(Self.folderConfiguration(
            path: "/Users/ibobby/Documents/Codex",
            backgroundPNGData: backgroundPNGData
        ), for: 5)
        let display = state.display(for: layout.keys[4])

        #expect(display.title == "Codex")
        #expect(display.subtitle == "/Users/ibobby/Documents/Codex")
        #expect(display.folderButtonContent?.displayName == "Codex")
        #expect(display.folderButtonContent?.backgroundPNGData == backgroundPNGData)
        #expect(state.folderPath(for: 5) == "/Users/ibobby/Documents/Codex")

        state.setFolderName(" 项目 ", for: 5)
        let namedDisplay = state.display(for: layout.keys[4])

        #expect(namedDisplay.title == "项目")
        #expect(namedDisplay.folderButtonContent?.displayName == "项目")
    }

    @Test func openFileFunctionDisplaysSelectedFileName() {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)
        let iconPNGData = Self.solidColorIconPNGData(color: .systemRed)
        let blurredIconPNGData = Self.solidColorIconPNGData(color: .systemBlue)

        state.assign(.openFile, to: 5)
        state.setFileConfiguration(Self.fileConfiguration(
            path: "/Users/ibobby/Documents/report.pdf",
            iconPNGData: iconPNGData,
            blurredIconPNGData: blurredIconPNGData
        ), for: 5)
        let display = state.display(for: layout.keys[4])

        #expect(display.title == "report.pdf")
        #expect(display.subtitle == "/Users/ibobby/Documents/report.pdf")
        #expect(display.fileButtonContent?.displayName == "report.pdf")
        #expect(display.fileButtonContent?.backgroundPNGData == iconPNGData)
        #expect(state.filePath(for: 5) == "/Users/ibobby/Documents/report.pdf")
        #expect(state.openFileConfiguration(for: 5).canUseIconBlur)

        state.setFileIconBlurEnabled(true, for: 5)
        let blurredDisplay = state.display(for: layout.keys[4])

        #expect(blurredDisplay.fileButtonContent?.backgroundPNGData == blurredIconPNGData)

        state.setFileName(" 报告 ", for: 5)
        let namedDisplay = state.display(for: layout.keys[4])

        #expect(namedDisplay.title == "报告")
        #expect(namedDisplay.fileButtonContent?.displayName == "报告")
    }

    @Test func buttonVisualConfigurationAppliesToAllButtonFunctions() {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)
        let backgroundPNGData = Self.solidColorIconPNGData(color: .systemRed)
        let blurredBackgroundPNGData = Self.solidColorIconPNGData(color: .systemBlue)
        let visual = DeckKeyVisualConfiguration(
            name: " 视觉 ",
            backgroundPNGData: backgroundPNGData,
            blurredBackgroundPNGData: blurredBackgroundPNGData,
            usesBlurredBackground: true,
            dimsBackground: false
        )

        state.clearFunction(keyID: 2)
        state.assign(.tally, to: 3)
        state.assign(.openFolder, to: 4)
        state.assign(.openFile, to: 5)
        state.assign(.connectSMBServer, to: 6)
        state.assign(.sub2API, to: 7)
        state.assign(.genshinStatus, to: 8)
        state.assign(.starRailStatus, to: 9)
        state.assign(.zenlessZoneStatus, to: 10)
        state.assign(.pageFolder, to: 11)

        for keyID in 2...11 {
            state.setButtonVisualConfiguration(visual, for: keyID)
            let display = state.display(for: layout.keys[keyID - 1])
            #expect(display.title == "视觉")
            #expect(display.buttonVisualContent.displayName == "视觉")
            #expect(display.buttonVisualContent.backgroundPNGData == blurredBackgroundPNGData)
            #expect(display.buttonVisualContent.dimsBackground == false)
            #expect(display.buttonVisualContent.hasCustomDisplayName)
            #expect(display.buttonVisualContent.hasCustomBackground)
        }

        let didEnterPage = state.enterPageFolder(keyID: 11)
        #expect(didEnterPage)
        state.setButtonVisualConfiguration(visual, for: 1)
        let backDisplay = state.display(for: layout.keys[0])
        #expect(backDisplay.title == "视觉")
        #expect(backDisplay.pageBackButtonContent?.displayName == "视觉")
        #expect(backDisplay.buttonVisualContent.backgroundPNGData == blurredBackgroundPNGData)
        #expect(backDisplay.buttonVisualContent.dimsBackground == false)
    }

    @Test func clearingCustomButtonBackgroundFallsBackToOriginalBackground() {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)
        let customBackgroundPNGData = Self.solidColorIconPNGData(color: .systemGreen)
        let iconPNGData = Self.solidColorIconPNGData(color: .systemRed)
        let blurredIconPNGData = Self.solidColorIconPNGData(color: .systemBlue)

        state.assign(.openFile, to: 5)
        state.setFileConfiguration(Self.fileConfiguration(
            path: "/Users/ibobby/Documents/report.pdf",
            iconPNGData: iconPNGData,
            blurredIconPNGData: blurredIconPNGData
        ), for: 5)
        state.setButtonVisualConfiguration(DeckKeyVisualConfiguration(backgroundPNGData: customBackgroundPNGData), for: 5)

        #expect(state.display(for: layout.keys[4]).buttonVisualContent.backgroundPNGData == customBackgroundPNGData)

        var fileVisual = state.buttonVisualConfiguration(for: 5) ?? DeckKeyVisualConfiguration()
        fileVisual.backgroundPNGData = nil
        fileVisual.blurredBackgroundPNGData = nil
        fileVisual.usesBlurredBackground = false
        state.setButtonVisualConfiguration(fileVisual, for: 5)

        let restoredFileDisplay = state.display(for: layout.keys[4])
        #expect(restoredFileDisplay.fileButtonContent?.backgroundPNGData == iconPNGData)
        #expect(!restoredFileDisplay.buttonVisualContent.hasCustomBackground)
        let didEnableFileBlur = state.setButtonVisualBlurEnabled(true, for: 5)
        #expect(didEnableFileBlur)
        #expect(state.display(for: layout.keys[4]).fileButtonContent?.backgroundPNGData == blurredIconPNGData)

        state.assign(.openFolder, to: 6)
        state.setButtonVisualConfiguration(DeckKeyVisualConfiguration(backgroundPNGData: customBackgroundPNGData), for: 6)
        var folderVisual = state.buttonVisualConfiguration(for: 6) ?? DeckKeyVisualConfiguration()
        folderVisual.backgroundPNGData = nil
        folderVisual.blurredBackgroundPNGData = nil
        folderVisual.usesBlurredBackground = false
        state.setButtonVisualConfiguration(folderVisual, for: 6)

        let restoredFolderDisplay = state.display(for: layout.keys[5])
        #expect(restoredFolderDisplay.folderButtonContent?.backgroundPNGData == nil)
        #expect(restoredFolderDisplay.buttonVisualContent.backgroundAssetName == FolderButtonContent.backgroundAssetName)
        #expect(!restoredFolderDisplay.buttonVisualContent.hasCustomBackground)
    }

    @Test func legacyOpenFolderConfigurationRequiresReselection() throws {
        let data = try #require(#"{"path":"/Users/ibobby/Documents"}"#.data(using: .utf8))
        let configuration = try JSONDecoder().decode(DeckKeyOpenFolderConfiguration.self, from: data)

        #expect(configuration.path == "/Users/ibobby/Documents")
        #expect(configuration.bookmarkData == nil)
        #expect(configuration.name.isEmpty)
        #expect(configuration.needsReselection)
        #expect(!configuration.canOpen)
        #expect(configuration.displayName == "Documents")
    }

    @Test func legacyOpenFileConfigurationRequiresReselection() throws {
        let data = try #require(#"{"path":"/Users/ibobby/Documents/report.pdf"}"#.data(using: .utf8))
        let configuration = try JSONDecoder().decode(DeckKeyOpenFileConfiguration.self, from: data)

        #expect(configuration.path == "/Users/ibobby/Documents/report.pdf")
        #expect(configuration.bookmarkData == nil)
        #expect(configuration.name.isEmpty)
        #expect(configuration.needsReselection)
        #expect(!configuration.canOpen)
        #expect(!configuration.canUseIconBlur)
        #expect(configuration.displayName == "report.pdf")
    }

    @Test func openFolderBookmarksUseReadOnlySecurityScope() {
        #expect(DeckKeyOpenFolderConfiguration.securityScopedBookmarkCreationOptions.contains(.withSecurityScope))
        #expect(DeckKeyOpenFolderConfiguration.securityScopedBookmarkCreationOptions.contains(.securityScopeAllowOnlyReadAccess))
        #expect(DeckKeyOpenFolderConfiguration.securityScopedBookmarkResolutionOptions.contains(.withSecurityScope))
        #expect(DeckKeyOpenFileConfiguration.securityScopedBookmarkCreationOptions.contains(.withSecurityScope))
        #expect(DeckKeyOpenFileConfiguration.securityScopedBookmarkCreationOptions.contains(.securityScopeAllowOnlyReadAccess))
        #expect(DeckKeyOpenFileConfiguration.securityScopedBookmarkResolutionOptions.contains(.withSecurityScope))
    }

    @Test func openFolderConfigurationPersistsBookmarkData() throws {
        let bookmarkData = try #require("bookmark-data".data(using: .utf8))
        let backgroundPNGData = Self.solidColorIconPNGData(color: .systemGreen)
        let configuration = Self.folderConfiguration(
            path: "/Users/ibobby/Documents",
            bookmarkData: bookmarkData,
            name: "下载",
            backgroundPNGData: backgroundPNGData
        )

        let encoded = try JSONEncoder().encode(configuration)
        let restored = try JSONDecoder().decode(DeckKeyOpenFolderConfiguration.self, from: encoded)

        #expect(restored.path == "/Users/ibobby/Documents")
        #expect(restored.bookmarkData == bookmarkData)
        #expect(restored.name == "下载")
        #expect(restored.backgroundPNGData == backgroundPNGData)
        #expect(restored.displayName == "下载")
        #expect(!restored.needsReselection)
        #expect(restored.canOpen)
    }

    @Test func openFileConfigurationPersistsBookmarkData() throws {
        let bookmarkData = try #require("bookmark-data".data(using: .utf8))
        let iconPNGData = Self.solidColorIconPNGData(color: .systemBlue)
        let blurredIconPNGData = Self.solidColorIconPNGData(color: .systemRed)
        let configuration = Self.fileConfiguration(
            path: "/Users/ibobby/Documents/report.pdf",
            bookmarkData: bookmarkData,
            name: "报告",
            iconPNGData: iconPNGData,
            blurredIconPNGData: blurredIconPNGData,
            usesBlurredIcon: true
        )

        let encoded = try JSONEncoder().encode(configuration)
        let restored = try JSONDecoder().decode(DeckKeyOpenFileConfiguration.self, from: encoded)

        #expect(restored.path == "/Users/ibobby/Documents/report.pdf")
        #expect(restored.bookmarkData == bookmarkData)
        #expect(restored.name == "报告")
        #expect(restored.iconPNGData == iconPNGData)
        #expect(restored.blurredIconPNGData == blurredIconPNGData)
        #expect(restored.usesBlurredIcon)
        #expect(restored.selectedIconPNGData == blurredIconPNGData)
        #expect(restored.displayName == "报告")
        #expect(!restored.needsReselection)
        #expect(restored.canOpen)
    }

    @Test func fileIconSnapshotStoresDirectAndBlurredLongEdge196Images() throws {
        let icon = Self.twoToneIconImage()
        let snapshot = try #require(FileIconSnapshot.snapshotData(for: icon))
        let directImage = try #require(NSBitmapImageRep(data: snapshot.iconPNGData))
        let blurredImage = try #require(NSBitmapImageRep(data: snapshot.blurredIconPNGData))

        #expect(max(directImage.pixelsWide, directImage.pixelsHigh) == 196)
        #expect(max(blurredImage.pixelsWide, blurredImage.pixelsHigh) == 196)
        #expect(snapshot.iconPNGData != snapshot.blurredIconPNGData)
    }

    @Test func connectSMBServerFunctionDisplaysNameAndPersistsNormalizedAddress() {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)

        state.assign(.connectSMBServer, to: 5)
        state.setSMBServerAddress("smb://server.local/share", for: 5)
        state.setSMBServerName("素材库", for: 5)
        let display = state.display(for: layout.keys[4])

        #expect(display.title == "素材库")
        #expect(display.subtitle == "server.local/share")
        #expect(display.smbServerButtonContent?.displayName == "素材库")
        #expect(state.smbServerAddress(for: 5) == "server.local/share")
        #expect(state.configuration(for: 5)?.buttonVisualConfiguration?.name == "素材库")
        #expect(state.configuration(for: 5)?.smbServer.fullURLString == "smb://server.local/share")
    }

    @Test func displayNameCommitCanAvoidChangingCurrentSelection() {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)

        state.assign(.openFolder, to: 4)
        state.setFolderConfiguration(Self.folderConfiguration(path: "/Users/ibobby/Documents"), for: 4)
        state.assign(.connectSMBServer, to: 5)
        state.setSMBServerAddress("nas.local/media", for: 5)
        state.assign(.openFile, to: 6)
        state.setFileConfiguration(Self.fileConfiguration(path: "/Users/ibobby/Documents/report.pdf"), for: 6)
        state.select(keyID: 2)

        state.setFolderName(" 资料 ", for: 4, selectsKey: false)
        state.setSMBServerName(" NAS ", for: 5, selectsKey: false)
        state.setFileName(" 报告 ", for: 6, selectsKey: false)

        #expect(state.selectedKeyID == 2)
        #expect(state.configuration(for: 4)?.buttonVisualConfiguration?.name == "资料")
        #expect(state.configuration(for: 5)?.buttonVisualConfiguration?.name == "NAS")
        #expect(state.configuration(for: 6)?.buttonVisualConfiguration?.name == "报告")
    }

    @Test func legacyBrightnessKeyFunctionIsNormalizedToNoFunction() {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(
            layout: layout,
            configurations: [
                6: DeckKeyConfiguration(function: .brightness),
            ]
        )
        let display = state.display(for: layout.keys[5])
        let didBeginPress = state.beginPress(keyID: 6)

        #expect(state.configuration(for: 6)?.function == DeckKeyFunction.none)
        #expect(!didBeginPress)
        #expect(display.title.isEmpty)
        #expect(display.subtitle.isEmpty)
    }

    @Test func userDefaultsStoreRestoresSavedKeyConfiguration() throws {
        let suiteName = "UlanziDeckSwiftTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let layout = DeckGridLayout.h200Prototype
        let store = UserDefaultsDeckConfigurationStore(
            defaults: defaults,
            storageKey: "deckConfiguration",
            brightnessStorageKey: "brightness"
        )
        var state = DeckGridInteractionState(layout: layout)
        state.setTallyDefaultValue(6, for: 3)
        state.triggerShortPress(keyID: 3)
        state.clearFunction(keyID: 8)
        state.assign(.openFolder, to: 9)
        state.setFolderConfiguration(Self.folderConfiguration(path: "/Users/ibobby/Documents"), for: 9)
        state.assign(.connectSMBServer, to: 10)
        state.setSMBServerAddress("smb://nas.local/media", for: 10)
        state.setSMBServerName("NAS", for: 10)
        state.assign(.openFile, to: 11)
        state.setFileConfiguration(Self.fileConfiguration(path: "/Users/ibobby/Documents/report.pdf"), for: 11)
        state.setFileName("报告", for: 11)

        store.saveInteractionState(state, for: layout)
        store.saveBrightnessPercent(140)

        let restored = try #require(store.loadInteractionState(for: layout))
        #expect(restored.tallyDefaultValue(for: 3) == 6)
        #expect(restored.tallyValue(for: 3) == 7)
        #expect(restored.configuration(for: 8)?.function == DeckKeyFunction.none)
        #expect(restored.configuration(for: 9)?.function == DeckKeyFunction.openFolder)
        #expect(restored.folderPath(for: 9) == "/Users/ibobby/Documents")
        #expect(restored.openFolderConfiguration(for: 9).bookmarkData == Data("bookmark".utf8))
        #expect(restored.configuration(for: 10)?.function == DeckKeyFunction.connectSMBServer)
        #expect(restored.smbServerAddress(for: 10) == "nas.local/media")
        #expect(restored.configuration(for: 10)?.buttonVisualConfiguration?.name == "NAS")
        #expect(restored.configuration(for: 11)?.function == DeckKeyFunction.openFile)
        #expect(restored.filePath(for: 11) == "/Users/ibobby/Documents/report.pdf")
        #expect(restored.openFileConfiguration(for: 11).bookmarkData == Data("bookmark".utf8))
        #expect(restored.configuration(for: 11)?.buttonVisualConfiguration?.name == "报告")
        #expect(store.loadBrightnessPercent() == 100)
        #expect(restored.pressedKeyIDs.isEmpty)
        #expect(restored.selectedKeyID == 1)
    }

    @Test func userDefaultsStoreMigratesLegacyFlatConfigurationToRootPage() throws {
        let suiteName = "UlanziDeckSwiftTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let storageKey = "deckConfiguration"
        let store = UserDefaultsDeckConfigurationStore(defaults: defaults, storageKey: storageKey)
        let legacyData = Data("""
        {
          "version": 1,
          "layoutIdentifier": "h200Prototype",
          "keys": [
            {
              "id": 3,
              "configuration": {
                "function": "openFolder",
                "openFolder": {
                  "path": "/Users/ibobby/Documents",
                  "bookmarkData": "Ym9va21hcms=",
                  "name": "文档"
                }
              }
            }
          ]
        }
        """.utf8)
        defaults.set(legacyData, forKey: storageKey)

        let restored = try #require(store.loadInteractionState(for: .h200Prototype))
        #expect(restored.currentPageID == DeckGridInteractionState.rootPageID)
        #expect(restored.navigationPathTitles == ["主页"])
        #expect(restored.configuration(for: 3)?.function == .openFolder)
        #expect(restored.openFolderConfiguration(for: 3).name == "文档")
        #expect(restored.configuration(for: 3)?.buttonVisualConfiguration?.name == "文档")
    }

    @Test func userDefaultsStorePersistsPageTreeAndRestoresToRootPage() throws {
        let suiteName = "UlanziDeckSwiftTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let layout = DeckGridLayout.h200Prototype
        let store = UserDefaultsDeckConfigurationStore(defaults: defaults, storageKey: "deckConfiguration")
        var state = DeckGridInteractionState(layout: layout)
        state.assign(.pageFolder, to: 2)
        state.enterPageFolder(keyID: 2)
        state.assign(.openFolder, to: 4)
        state.setFolderConfiguration(Self.folderConfiguration(path: "/Users/ibobby/Documents/Nested"), for: 4)

        store.saveInteractionState(state, for: layout)
        var restored = try #require(store.loadInteractionState(for: layout))

        #expect(restored.currentPageID == DeckGridInteractionState.rootPageID)
        #expect(restored.navigationPathTitles == ["主页"])
        #expect(restored.configuration(for: 2)?.function == .pageFolder)
        let didEnterRestoredPage = restored.enterPageFolder(keyID: 2)
        #expect(didEnterRestoredPage)
        #expect(restored.configuration(for: 1)?.function == .pageBack)
        #expect(restored.configuration(for: 4)?.function == .openFolder)
        #expect(restored.folderPath(for: 4) == "/Users/ibobby/Documents/Nested")
    }

    @Test func userDefaultsStoreIgnoresBrokenConfigurationData() throws {
        let suiteName = "UlanziDeckSwiftTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let storageKey = "deckConfiguration"
        let store = UserDefaultsDeckConfigurationStore(defaults: defaults, storageKey: storageKey)
        defaults.set(Data("不是 JSON".utf8), forKey: storageKey)

        #expect(store.loadInteractionState(for: .h200Prototype) == nil)
    }

    @Test func mihoyoGameRefreshIntervalDefaultsClampsAndPersists() throws {
        let legacyData = Data(#"{"function":"genshinStatus"}"#.utf8)
        let legacyConfiguration = try JSONDecoder().decode(DeckKeyConfiguration.self, from: legacyData)
        #expect(legacyConfiguration.mihoyoGame.refreshIntervalMinutes == 30)

        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)
        state.assign(.genshinStatus, to: 3)

        #expect(state.mihoyoGameConfiguration(for: 3).refreshIntervalMinutes == 30)
        let didSetMinimumInterval = state.setMihoyoGameRefreshIntervalMinutes(0, for: 3)
        #expect(didSetMinimumInterval)
        #expect(state.mihoyoGameConfiguration(for: 3).refreshIntervalMinutes == 1)
        let didSetMaximumInterval = state.setMihoyoGameRefreshIntervalMinutes(2_000, for: 3)
        #expect(didSetMaximumInterval)
        #expect(state.mihoyoGameConfiguration(for: 3).refreshIntervalMinutes == 1_440)
        let didSetInterval = state.setMihoyoGameRefreshIntervalMinutes(45, for: 3)
        #expect(didSetInterval)

        let configuration = try #require(state.configuration(for: 3))
        let data = try JSONEncoder().encode(configuration)
        let restored = try JSONDecoder().decode(DeckKeyConfiguration.self, from: data)
        #expect(restored.mihoyoGame.refreshIntervalMinutes == 45)
        #expect(restored.mihoyoGame.lastResult == nil)
    }

    @Test func sub2APICapacityResponseParsesGroupNamesAndIDs() throws {
        let data = Data("""
        {"code":0,"message":"success","data":{"items":[{"group_id":61711,"group_name":"OpenAI账号模式","group_platform":"openai","concurrency_used":1,"concurrency_max":2131,"sessions_used":0,"sessions_max":0,"rpm_used":0,"rpm_max":0},{"group_id":18,"group_name":"TEAM共享号池","group_platform":"openai","concurrency_used":0,"concurrency_max":0,"sessions_used":0,"sessions_max":0,"rpm_used":0,"rpm_max":0},{"group_id":59,"group_name":"CODEX【兜底】","group_platform":"openai","concurrency_used":0,"concurrency_max":0,"sessions_used":0,"sessions_max":0,"rpm_used":0,"rpm_max":0},{"group_id":1197,"group_name":"FREE共享号池","group_platform":"openai","concurrency_used":0,"concurrency_max":3,"sessions_used":0,"sessions_max":0,"rpm_used":0,"rpm_max":0},{"group_id":1198,"group_name":"PRO共享号池","group_platform":"openai","concurrency_used":6,"concurrency_max":705,"sessions_used":0,"sessions_max":0,"rpm_used":0,"rpm_max":0},{"group_id":1215,"group_name":"PLUS共享号池","group_platform":"openai","concurrency_used":37,"concurrency_max":3332,"sessions_used":0,"sessions_max":0,"rpm_used":0,"rpm_max":0},{"group_id":63196,"group_name":"OPENAI官key【生图专用· 倍率*8】","group_platform":"openai","concurrency_used":0,"concurrency_max":10000,"sessions_used":0,"sessions_max":0,"rpm_used":0,"rpm_max":0}],"total":{"group_id":0,"group_name":"","group_platform":"","concurrency_used":44,"concurrency_max":16171,"sessions_used":0,"sessions_max":0,"rpm_used":0,"rpm_max":0}}}
        """.utf8)

        let response = try JSONDecoder().decode(Sub2APICapacityResponse.self, from: data)

        #expect(response.code == .success)
        #expect(response.data?.items.map(\.groupID) == [61711, 18, 59, 1197, 1198, 1215, 63196])
        let plusPool = try #require(response.data?.items.first(where: { $0.groupID == 1215 }))
        #expect(plusPool.groupName == "PLUS共享号池")
        #expect(plusPool.availableConcurrency == 3295)
        #expect(response.data?.total.concurrencyMax == 16171)
    }

    @Test func sub2APIStringTokenErrorCodesDecodeAsBusinessErrors() throws {
        let invalidTokenData = Data(#"{"code":"INVALID_TOKEN","message":"Invalid token"}"#.utf8)
        let expiredTokenData = Data(#"{"code":"TOKEN_EXPIRED","message":"Token has expired"}"#.utf8)

        let invalidTokenResponse = try JSONDecoder().decode(Sub2APICapacityResponse.self, from: invalidTokenData)
        let expiredTokenResponse = try JSONDecoder().decode(Sub2APICapacityResponse.self, from: expiredTokenData)

        #expect(invalidTokenResponse.code == .invalidToken)
        #expect(invalidTokenResponse.indicatesInvalidToken)
        #expect(!invalidTokenResponse.indicatesTokenExpired)
        #expect(invalidTokenResponse.data == nil)
        #expect(expiredTokenResponse.code == .tokenExpired)
        #expect(expiredTokenResponse.indicatesTokenExpired)
        #expect(!expiredTokenResponse.indicatesInvalidToken)
        #expect(expiredTokenResponse.data == nil)
    }

    @MainActor
    @Test func fetchingSub2APIGroupListPopulatesOptionsAndPersistsSelectedIDOnly() async throws {
        let plusPool = Self.sub2APICapacityItem(groupID: 1215, groupName: "PLUS共享号池", availableConcurrency: 3078)
        let freePool = Self.sub2APICapacityItem(groupID: 1197, groupName: "FREE共享号池", availableConcurrency: 3)
        let fetcher = FakeSub2APIFetcher(
            results: [.success(item: plusPool)],
            groupListResults: [.success(items: [freePool, plusPool])]
        )
        let store = FakeDeckConfigurationStore()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.notConnected]),
            syncer: FakeH200DeckSyncer(),
            configurationStore: store,
            sub2APIFetcher: fetcher
        )

        model.selectKey(keyID: 3)
        model.assignSelectedFunction(.sub2API)
        model.setSelectedSub2APIBaseURL("api.example.com")
        model.setSelectedSub2APIBearerKey("token")

        try await Self.waitUntil {
            fetcher.groupListRequests.count == 1
                && model.interactionState.sub2APIConfiguration(for: 3).groupListState == .success(items: [freePool, plusPool])
        }

        model.setSelectedSub2APITargetGroupID(1215)

        try await Self.waitUntil {
            fetcher.requests.count == 1
                && model.interactionState.sub2APIConfiguration(for: 3).lastResult == .success(item: plusPool)
        }

        let configuration = try #require(model.interactionState.configuration(for: 3))
        #expect(configuration.sub2API.targetGroupID == 1215)
        #expect(configuration.sub2API.displayName == "PLUS共享号池")
        #expect(fetcher.groupListRequests == [
            FakeSub2APIFetcher.GroupListRequest(baseURL: "api.example.com", bearerKey: "token"),
        ])
        #expect(fetcher.requests == [
            FakeSub2APIFetcher.Request(baseURL: "api.example.com", targetGroupID: 1215, bearerKey: "token"),
        ])
        #expect(store.savedStates.last?.sub2APIConfiguration(for: 3).targetGroupID == 1215)

        let data = try JSONEncoder().encode(configuration)
        let restored = try JSONDecoder().decode(DeckKeyConfiguration.self, from: data)
        #expect(restored.sub2API.targetGroupID == 1215)
        #expect(restored.sub2API.groupListState == .idle)
        #expect(restored.sub2API.lastResult == nil)
    }

    @MainActor
    @Test func fetchingSub2APIGroupListDistinguishesInvalidAndExpiredBearerKey() async throws {
        let fetcher = FakeSub2APIFetcher(groupListResults: [.invalidToken, .tokenExpired])
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.notConnected]),
            syncer: FakeH200DeckSyncer(),
            configurationStore: FakeDeckConfigurationStore(),
            sub2APIFetcher: fetcher,
            sub2APIGroupListMinimumIntervalNanoseconds: 1_000_000
        )

        model.selectKey(keyID: 3)
        model.assignSelectedFunction(.sub2API)
        model.setSelectedSub2APIBaseURL("api.example.com")
        model.setSelectedSub2APIBearerKey("token")

        try await Self.waitUntil {
            model.interactionState.sub2APIConfiguration(for: 3).groupListState == .invalidToken
        }

        model.refreshSelectedSub2APIGroupList()
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(fetcher.groupListRequests == [
            FakeSub2APIFetcher.GroupListRequest(baseURL: "api.example.com", bearerKey: "token"),
        ])

        model.setSelectedSub2APIBearerKey("new-token")

        try await Self.waitUntil {
            model.interactionState.sub2APIConfiguration(for: 3).groupListState == .tokenExpired
        }

        #expect(fetcher.groupListRequests == [
            FakeSub2APIFetcher.GroupListRequest(baseURL: "api.example.com", bearerKey: "token"),
            FakeSub2APIFetcher.GroupListRequest(baseURL: "api.example.com", bearerKey: "new-token"),
        ])
    }

    @MainActor
    @Test func sub2APIBaseURLAndBearerChangesThrottleGroupListFetchWithoutRenderingTokenError() async throws {
        let syncer = FakeH200DeckSyncer()
        let fetcher = FakeSub2APIFetcher(groupListResults: [.invalidToken, .tokenExpired])
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore(),
            sub2APIFetcher: fetcher,
            sub2APIGroupListMinimumIntervalNanoseconds: 200_000_000
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        model.selectKey(keyID: 3)
        model.assignSelectedFunction(.sub2API)
        model.setSelectedSub2APIBaseURL("api.example.com")
        model.setSelectedSub2APIBearerKey("old-token")

        try await Self.waitUntil {
            fetcher.groupListRequests.count == 1
                && model.interactionState.sub2APIConfiguration(for: 3).groupListState == .invalidToken
        }

        model.setSelectedSub2APIBearerKey("token")
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(fetcher.groupListRequests.count == 1)

        try await Self.waitUntil {
            fetcher.groupListRequests.count == 2
                && model.interactionState.sub2APIConfiguration(for: 3).groupListState == .tokenExpired
        }

        #expect(fetcher.groupListRequests == [
            FakeSub2APIFetcher.GroupListRequest(baseURL: "api.example.com", bearerKey: "old-token"),
            FakeSub2APIFetcher.GroupListRequest(baseURL: "api.example.com", bearerKey: "token"),
        ])
        #expect(!syncer.partialDisplays.flatMap { $0 }.contains { $0.title == "令牌" })
        let latestKeyDisplay = try #require(syncer.partialDisplays.flatMap { $0 }.last { $0.id == 3 })
        #expect(latestKeyDisplay.title == "号池")
        #expect(latestKeyDisplay.subtitle == "未配置")
    }

    @MainActor
    @Test func sub2APIRefreshCountdownStartsAfterDisplayPackageFinishes() async throws {
        let firstItem = Self.sub2APICapacityItem(groupID: 1215, groupName: "PLU", availableConcurrency: 3078)
        let secondItem = Self.sub2APICapacityItem(groupID: 1215, groupName: "PLU", availableConcurrency: 3060)
        let syncer = FakeH200DeckSyncer(packageDelayNanoseconds: 200_000_000)
        let fetcher = FakeSub2APIFetcher(
            results: [.success(item: firstItem), .success(item: secondItem)],
            defaultResult: .success(item: secondItem)
        )
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore(),
            sub2APIFetcher: fetcher,
            sub2APIRefreshSecondDuration: 0.01,
            sub2APIGroupListMinimumIntervalNanoseconds: 1_000_000_000
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        model.selectKey(keyID: 3)
        model.assignSelectedFunction(.sub2API)
        model.setSelectedSub2APIBaseURL("api.example.com")
        model.setSelectedSub2APIBearerKey("token")
        model.setSelectedSub2APIRefreshInterval(5)
        try await Self.waitUntil {
            syncer.partialDisplays.count >= 3
        }

        model.setSelectedSub2APITargetGroupID(1215)

        try await Self.waitUntil {
            fetcher.requests.count == 1
        }
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(fetcher.requests.count == 1)

        try await Self.waitUntil {
            fetcher.requests.count >= 2
                && model.interactionState.sub2APIConfiguration(for: 3).lastResult == .success(item: secondItem)
        }

        #expect(Array(fetcher.requests.prefix(2)) == [
            FakeSub2APIFetcher.Request(baseURL: "api.example.com", targetGroupID: 1215, bearerKey: "token"),
            FakeSub2APIFetcher.Request(baseURL: "api.example.com", targetGroupID: 1215, bearerKey: "token"),
        ])
    }

    @MainActor
    @Test func sub2APITokenFailurePausesRequestsUntilBearerKeyChanges() async throws {
        let restoredItem = Self.sub2APICapacityItem(groupID: 1215, groupName: "PLU", availableConcurrency: 3050)
        let fetcher = FakeSub2APIFetcher(
            results: [.invalidToken, .success(item: restoredItem)],
            defaultResult: .success(item: restoredItem)
        )
        let layout = DeckGridLayout.h200Prototype
        var loadedState = DeckGridInteractionState(layout: layout)
        loadedState.assign(.sub2API, to: 3)
        loadedState.setSub2APIBaseURL("api.example.com", for: 3)
        loadedState.setSub2APITargetGroupID(1215, for: 3)
        loadedState.setSub2APIBearerKey("old-token", for: 3)
        loadedState.setSub2APIRefreshInterval(5, for: 3)
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore(loadedState: loadedState),
            sub2APIFetcher: fetcher,
            sub2APIRefreshSecondDuration: 0.01
        )

        model.checkOnLaunch()

        try await Self.waitUntil {
            fetcher.requests.count == 1
                && model.interactionState.configuration(for: 3)?.sub2API.lastResult == .invalidToken
        }
        try await Task.sleep(nanoseconds: 120_000_000)
        #expect(fetcher.requests.count == 1)

        syncer.emitInput(H200InputEvent(state: 1, index: 2, type: .button, action: .press))
        syncer.emitInput(H200InputEvent(state: 0, index: 2, type: .button, action: .release))
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(fetcher.requests.count == 1)

        model.selectKey(keyID: 3)
        model.setSelectedSub2APIBearerKey("old-token")
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(fetcher.requests.count == 1)

        model.setSelectedSub2APIBaseURL("api2.example.com")
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(fetcher.requests.count == 1)

        model.setSelectedSub2APIBearerKey("new-token")

        try await Self.waitUntil {
            fetcher.requests.count >= 2
                && model.interactionState.configuration(for: 3)?.sub2API.lastResult == .success(item: restoredItem)
        }

        #expect(Array(fetcher.requests.prefix(2)) == [
            FakeSub2APIFetcher.Request(baseURL: "api.example.com", targetGroupID: 1215, bearerKey: "old-token"),
            FakeSub2APIFetcher.Request(baseURL: "api2.example.com", targetGroupID: 1215, bearerKey: "new-token"),
        ])
    }

    @MainActor
    @Test func sub2APITokenPauseMovesWithSwappedConfiguration() async throws {
        let restoredItem = Self.sub2APICapacityItem(groupID: 1215, groupName: "PLU", availableConcurrency: 3050)
        let fetcher = FakeSub2APIFetcher(
            results: [.invalidToken, .success(item: restoredItem)],
            defaultResult: .success(item: restoredItem)
        )
        let layout = DeckGridLayout.h200Prototype
        var loadedState = DeckGridInteractionState(layout: layout)
        loadedState.assign(.sub2API, to: 3)
        loadedState.setSub2APIBaseURL("api.example.com", for: 3)
        loadedState.setSub2APITargetGroupID(1215, for: 3)
        loadedState.setSub2APIBearerKey("old-token", for: 3)
        loadedState.setSub2APIRefreshInterval(5, for: 3)
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore(loadedState: loadedState),
            sub2APIFetcher: fetcher,
            sub2APIRefreshSecondDuration: 0.01
        )

        model.checkOnLaunch()

        try await Self.waitUntil {
            fetcher.requests.count == 1
                && model.interactionState.configuration(for: 3)?.sub2API.lastResult == .invalidToken
        }

        model.swapSquareKeyConfigurations(sourceKeyID: 3, targetKeyID: 4)
        try await Task.sleep(nanoseconds: 120_000_000)
        #expect(fetcher.requests.count == 1)
        #expect(model.interactionState.configuration(for: 3)?.function != .sub2API)
        #expect(model.interactionState.configuration(for: 4)?.function == .sub2API)

        syncer.emitInput(H200InputEvent(state: 1, index: 3, type: .button, action: .press))
        syncer.emitInput(H200InputEvent(state: 0, index: 3, type: .button, action: .release))
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(fetcher.requests.count == 1)

        model.selectKey(keyID: 4)
        model.setSelectedSub2APIBearerKey("new-token")

        try await Self.waitUntil {
            fetcher.requests.count >= 2
                && model.interactionState.configuration(for: 4)?.sub2API.lastResult == .success(item: restoredItem)
        }

        #expect(Array(fetcher.requests.prefix(2)) == [
            FakeSub2APIFetcher.Request(baseURL: "api.example.com", targetGroupID: 1215, bearerKey: "old-token"),
            FakeSub2APIFetcher.Request(baseURL: "api.example.com", targetGroupID: 1215, bearerKey: "new-token"),
        ])
    }

    @MainActor
    @Test func sub2APITokenPauseIsClearedWhenInstanceIsDestroyed() async throws {
        let fetcher = FakeSub2APIFetcher(
            results: [.invalidToken, .invalidToken],
            defaultResult: .invalidToken
        )
        let layout = DeckGridLayout.h200Prototype
        var loadedState = DeckGridInteractionState(layout: layout)
        loadedState.assign(.sub2API, to: 3)
        loadedState.setSub2APIBaseURL("api.example.com", for: 3)
        loadedState.setSub2APITargetGroupID(1215, for: 3)
        loadedState.setSub2APIBearerKey("stale-token", for: 3)
        loadedState.setSub2APIRefreshInterval(5, for: 3)
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: FakeH200DeckSyncer(),
            configurationStore: FakeDeckConfigurationStore(loadedState: loadedState),
            sub2APIFetcher: fetcher,
            sub2APIRefreshSecondDuration: 0.01
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            fetcher.requests.count == 1
                && model.interactionState.configuration(for: 3)?.sub2API.lastResult == .invalidToken
        }

        model.clearKeyFunction(keyID: 3)
        #expect(model.interactionState.configuration(for: 3)?.sub2API.lastResult == nil)
        model.selectKey(keyID: 3)
        model.assignSelectedFunction(.sub2API)
        model.setSelectedSub2APIBaseURL("api.example.com")
        model.setSelectedSub2APIBearerKey("stale-token")
        model.setSelectedSub2APITargetGroupID(1215)

        try await Self.waitUntil {
            fetcher.requests.count == 2
                && model.interactionState.configuration(for: 3)?.sub2API.lastResult == .invalidToken
        }

        #expect(fetcher.requests == [
            FakeSub2APIFetcher.Request(baseURL: "api.example.com", targetGroupID: 1215, bearerKey: "stale-token"),
            FakeSub2APIFetcher.Request(baseURL: "api.example.com", targetGroupID: 1215, bearerKey: "stale-token"),
        ])
    }

    @MainActor
    @Test func sub2APITimerKeepsRemainingDelayAfterSwap() async throws {
        let firstItem = Self.sub2APICapacityItem(groupID: 1215, groupName: "PLU", availableConcurrency: 3050)
        let secondItem = Self.sub2APICapacityItem(groupID: 1215, groupName: "PLU", availableConcurrency: 3040)
        let fetcher = FakeSub2APIFetcher(
            results: [.success(item: firstItem), .success(item: secondItem)],
            defaultResult: .success(item: secondItem)
        )
        let layout = DeckGridLayout.h200Prototype
        var loadedState = DeckGridInteractionState(layout: layout)
        loadedState.assign(.sub2API, to: 3)
        loadedState.setSub2APIBaseURL("api.example.com", for: 3)
        loadedState.setSub2APITargetGroupID(1215, for: 3)
        loadedState.setSub2APIBearerKey("token", for: 3)
        loadedState.setSub2APIRefreshInterval(5, for: 3)
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: FakeH200DeckSyncer(),
            configurationStore: FakeDeckConfigurationStore(loadedState: loadedState),
            sub2APIFetcher: fetcher,
            sub2APIRefreshSecondDuration: 0.02
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            fetcher.requests.count == 1
                && model.interactionState.configuration(for: 3)?.sub2API.lastResult == .success(item: firstItem)
        }
        try await Task.sleep(nanoseconds: 40_000_000)

        model.swapSquareKeyConfigurations(sourceKeyID: 3, targetKeyID: 4)
        try await Task.sleep(nanoseconds: 80_000_000)

        #expect(fetcher.requests.count >= 2)
        #expect(model.interactionState.configuration(for: 3)?.function != .sub2API)
        #expect(model.interactionState.configuration(for: 4)?.sub2API.lastResult == .success(item: secondItem))
    }

    @MainActor
    @Test func sub2APIDisplaySyncCompletionDoesNotScheduleAfterInstanceIsDestroyed() async throws {
        let item = Self.sub2APICapacityItem(groupID: 1215, groupName: "PLU", availableConcurrency: 3050)
        let fetcher = FakeSub2APIFetcher(
            results: [.success(item: item)],
            defaultResult: .success(item: item)
        )
        let syncer = FakeH200DeckSyncer(packageDelayNanoseconds: 160_000_000)
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore(),
            sub2APIFetcher: fetcher,
            sub2APIRefreshSecondDuration: 0.01
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        model.selectKey(keyID: 3)
        model.assignSelectedFunction(.sub2API)
        model.setSelectedSub2APIBaseURL("api.example.com")
        model.setSelectedSub2APIBearerKey("token")
        model.setSelectedSub2APITargetGroupID(1215)
        try await Self.waitUntil {
            fetcher.requests.count == 1
                && model.interactionState.configuration(for: 3)?.sub2API.lastResult == .success(item: item)
        }

        model.assignSelectedFunction(.tally)
        try await Task.sleep(nanoseconds: 260_000_000)

        #expect(fetcher.requests.count == 1)
        #expect(model.interactionState.configuration(for: 3)?.function == .tally)
    }

    @MainActor
    @Test func sub2APIGroupListDelayedRefreshFollowsInstanceAfterSwap() async throws {
        let oldPool = Self.sub2APICapacityItem(groupID: 1197, groupName: "FREE", availableConcurrency: 10)
        let newPool = Self.sub2APICapacityItem(groupID: 1215, groupName: "PLUS", availableConcurrency: 3050)
        let fetcher = FakeSub2APIFetcher(
            groupListResults: [.success(items: [oldPool]), .success(items: [newPool])],
            defaultGroupListResult: .success(items: [newPool])
        )
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: FakeH200DeckSyncer(),
            configurationStore: FakeDeckConfigurationStore(),
            sub2APIFetcher: fetcher,
            sub2APIGroupListMinimumIntervalNanoseconds: 120_000_000
        )

        model.checkOnLaunch()
        model.selectKey(keyID: 3)
        model.assignSelectedFunction(.sub2API)
        model.setSelectedSub2APIBaseURL("api.example.com")
        model.setSelectedSub2APIBearerKey("old-token")
        try await Self.waitUntil {
            fetcher.groupListRequests.count == 1
                && model.interactionState.sub2APIConfiguration(for: 3).groupListState == .success(items: [oldPool])
        }

        model.setSelectedSub2APIBearerKey("new-token")
        model.swapSquareKeyConfigurations(sourceKeyID: 3, targetKeyID: 4)

        try await Self.waitUntil {
            fetcher.groupListRequests.count == 2
                && model.interactionState.sub2APIConfiguration(for: 4).groupListState == .success(items: [newPool])
        }

        #expect(fetcher.groupListRequests == [
            FakeSub2APIFetcher.GroupListRequest(baseURL: "api.example.com", bearerKey: "old-token"),
            FakeSub2APIFetcher.GroupListRequest(baseURL: "api.example.com", bearerKey: "new-token"),
        ])
    }

    @MainActor
    @Test func sub2APIPageNavigationPausesTimerAndRefreshesWhenReturningAfterDueTime() async throws {
        let firstItem = Self.sub2APICapacityItem(groupID: 1215, groupName: "PLU", availableConcurrency: 3050)
        let secondItem = Self.sub2APICapacityItem(groupID: 1215, groupName: "PLU", availableConcurrency: 3040)
        let fetcher = FakeSub2APIFetcher(
            results: [.success(item: firstItem), .success(item: secondItem)],
            defaultResult: .success(item: secondItem)
        )
        let layout = DeckGridLayout.h200Prototype
        var loadedState = DeckGridInteractionState(layout: layout)
        loadedState.assign(.sub2API, to: 3)
        loadedState.setSub2APIBaseURL("api.example.com", for: 3)
        loadedState.setSub2APITargetGroupID(1215, for: 3)
        loadedState.setSub2APIBearerKey("token", for: 3)
        loadedState.setSub2APIRefreshInterval(5, for: 3)
        loadedState.assign(.pageFolder, to: 4)
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: FakeH200DeckSyncer(),
            configurationStore: FakeDeckConfigurationStore(loadedState: loadedState),
            sub2APIFetcher: fetcher,
            sub2APIRefreshSecondDuration: 0.02
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            fetcher.requests.count == 1
                && model.interactionState.configuration(for: 3)?.sub2API.lastResult == .success(item: firstItem)
        }
        try await Task.sleep(nanoseconds: 40_000_000)

        model.navigateKey(keyID: 4)
        try await Task.sleep(nanoseconds: 120_000_000)
        #expect(fetcher.requests.count == 1)

        model.navigateKey(keyID: 1)
        try await Self.waitUntil {
            fetcher.requests.count >= 2
                && model.interactionState.configuration(for: 3)?.sub2API.lastResult == .success(item: secondItem)
        }
    }

    @MainActor
    @Test func staleSub2APITokenFailureIsIgnoredAfterSwitchingFunction() async throws {
        let restoredItem = Self.sub2APICapacityItem(groupID: 1215, groupName: "PLU", availableConcurrency: 3050)
        let fetcher = FakeSub2APIFetcher(
            results: [.invalidToken, .success(item: restoredItem)],
            defaultResult: .success(item: restoredItem),
            fetchDelayNanoseconds: 80_000_000
        )
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore(),
            sub2APIFetcher: fetcher
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        model.selectKey(keyID: 3)
        model.assignSelectedFunction(.sub2API)
        model.setSelectedSub2APIBaseURL("api.example.com")
        model.setSelectedSub2APIBearerKey("old-token")
        model.setSelectedSub2APITargetGroupID(1215)
        try await Self.waitUntil {
            fetcher.requests.count == 1
        }

        model.assignSelectedFunction(.tally)
        try await Task.sleep(nanoseconds: 120_000_000)
        #expect(model.interactionState.configuration(for: 3)?.function == .tally)
        #expect(model.interactionState.configuration(for: 3)?.sub2API.lastResult == nil)

        model.assignSelectedFunction(.sub2API)

        try await Self.waitUntil {
            fetcher.requests.count >= 2
                && model.interactionState.configuration(for: 3)?.sub2API.lastResult == .success(item: restoredItem)
        }

        #expect(Array(fetcher.requests.prefix(2)) == [
            FakeSub2APIFetcher.Request(baseURL: "api.example.com", targetGroupID: 1215, bearerKey: "old-token"),
            FakeSub2APIFetcher.Request(baseURL: "api.example.com", targetGroupID: 1215, bearerKey: "old-token"),
        ])
    }

    @MainActor
    @Test func sub2APIHighImpactSameValueWritesDoNotPersistOrRequest() {
        let layout = DeckGridLayout.h200Prototype
        var loadedState = DeckGridInteractionState(layout: layout)
        loadedState.assign(.sub2API, to: 3)
        loadedState.setSub2APIBaseURL("api.example.com", for: 3)
        loadedState.setSub2APITargetGroupID(1215, for: 3)
        loadedState.setSub2APIBearerKey("token", for: 3)
        loadedState.setSub2APIRefreshInterval(5, for: 3)
        let fetcher = FakeSub2APIFetcher()
        let store = FakeDeckConfigurationStore(loadedState: loadedState)
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.notConnected]),
            syncer: FakeH200DeckSyncer(),
            configurationStore: store,
            sub2APIFetcher: fetcher
        )

        model.selectKey(keyID: 3)
        model.setSelectedSub2APIBaseURL("  api.example.com  ")
        model.setSelectedSub2APITargetGroupID(1215)
        model.setSelectedSub2APIRefreshInterval(1)
        model.setSelectedSub2APIBearerKey("token")

        #expect(store.savedStates.isEmpty)
        #expect(fetcher.requests.isEmpty)
        #expect(fetcher.groupListRequests.isEmpty)
    }

    @MainActor
    @Test func sub2APINetworkErrorKeepsAutomaticRefreshRunning() async throws {
        let item = Self.sub2APICapacityItem(groupID: 1215, groupName: "PLU", availableConcurrency: 3040)
        let fetcher = FakeSub2APIFetcher(
            results: [.networkError("网络未连接"), .success(item: item)],
            defaultResult: .success(item: item)
        )
        let layout = DeckGridLayout.h200Prototype
        var loadedState = DeckGridInteractionState(layout: layout)
        loadedState.assign(.sub2API, to: 3)
        loadedState.setSub2APIBaseURL("api.example.com", for: 3)
        loadedState.setSub2APITargetGroupID(1215, for: 3)
        loadedState.setSub2APIBearerKey("token", for: 3)
        loadedState.setSub2APIRefreshInterval(5, for: 3)
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: FakeH200DeckSyncer(),
            configurationStore: FakeDeckConfigurationStore(loadedState: loadedState),
            sub2APIFetcher: fetcher,
            sub2APIRefreshSecondDuration: 0.01
        )

        model.checkOnLaunch()

        try await Self.waitUntil {
            fetcher.requests.count >= 2
                && model.interactionState.configuration(for: 3)?.sub2API.lastResult == .success(item: item)
        }

        #expect(Array(fetcher.requests.prefix(2)) == [
            FakeSub2APIFetcher.Request(baseURL: "api.example.com", targetGroupID: 1215, bearerKey: "token"),
            FakeSub2APIFetcher.Request(baseURL: "api.example.com", targetGroupID: 1215, bearerKey: "token"),
        ])
    }

    @Test func h200ProtocolInterfaceMatchesObservedReportShape() {
        let identity = Self.protocolInterfaceIdentity()

        #expect(identity.isProtocolInterface)
    }

    @Test func h200KeyboardInterfaceIsNotProtocolInterface() {
        let identity = H200DeviceIdentity(
            vendorID: H200DeviceTarget.vendorID,
            productID: H200DeviceTarget.productID,
            locationID: 0x01124300,
            primaryUsagePage: 1,
            primaryUsage: 6,
            maxInputReportSize: 8,
            maxOutputReportSize: 1,
            serialNumber: "70973ca7355917c7",
            manufacturer: "rockchip",
            product: ""
        )

        #expect(!identity.isProtocolInterface)
    }

    @MainActor
    @Test func launchCheckShowsRetryAlertWhenH200IsMissing() async throws {
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.notConnected]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore()
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            model.status == .notConnected
        }

        #expect(model.status == .notConnected)
        #expect(model.alert?.title == "未检测到 H200")
        #expect(syncer.sentDisplays.isEmpty)
    }

    @MainActor
    @Test func managerExclusiveAccessShowsOccupiedPortAlert() async throws {
        let code = Self.exclusiveAccessReturnCode()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.communicationPortOccupied(code)]),
            syncer: FakeH200DeckSyncer(),
            configurationStore: FakeDeckConfigurationStore()
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            model.status == .communicationPortOccupied(code)
        }

        #expect(model.status == .communicationPortOccupied(code))
        #expect(model.alert?.title == "H200 通信端口被占用")
        #expect(model.alert?.message.contains("有其他应用正在占用 H200 通信端口") == true)
        #expect(model.alert?.message.contains("kIOReturnExclusiveAccess") == true)
    }

    @Test func exclusiveAccessReturnCodeMeansOccupiedPort() {
        let code = Self.exclusiveAccessReturnCode()

        #expect(code.name == "kIOReturnExclusiveAccess")
        #expect(code.indicatesOccupiedPort)
    }

    @MainActor
    @Test func retryUpdatesStateWhenH200Appears() async throws {
        let connectedIdentity = Self.protocolInterfaceIdentity()
        let syncer = FakeH200DeckSyncer(results: [
            .success(H200DeckSyncSummary(payloadByteCount: 2048, packetCount: 2, displayCount: 14)),
        ])
        let model = H200ConnectionModel(discovery: FakeH200Discovery(results: [
            .notConnected,
            .connected(connectedIdentity),
        ]), syncer: syncer, configurationStore: FakeDeckConfigurationStore())

        model.checkOnLaunch()
        model.retry()
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(model.status == .connected(connectedIdentity))
        #expect(model.connectedDevice == connectedIdentity)
        #expect(model.syncSummary?.displayCount == 14)
        #expect(model.alert == nil)
        #expect(syncer.sentDisplays.count == 1)
    }

    @MainActor
    @Test func successfulLaunchSendsDisplaysMatchingTheVisibleGrid() async throws {
        let connectedIdentity = Self.protocolInterfaceIdentity()
        let syncer = FakeH200DeckSyncer(results: [
            .success(H200DeckSyncSummary(payloadByteCount: 4096, packetCount: 4, displayCount: 14)),
        ])
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(connectedIdentity)]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore()
        )

        model.checkOnLaunch()

        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary?.packetCount == 4
        }
        #expect(syncer.sentDisplays.first?.map(\.title) == Array(repeating: "0", count: 14))
        #expect(syncer.sentDisplays.first?.allSatisfy { $0.subtitle == "默认 0" } == true)
        #expect(syncer.sentDisplays.first?.last?.isWide == true)
        #expect(model.syncSummary?.packetCount == 4)
    }

    @MainActor
    @Test func launchUsesPersistedConfigurationWhenSyncingDevice() async throws {
        let layout = DeckGridLayout.h200Prototype
        var persistedState = DeckGridInteractionState(layout: layout)
        persistedState.setTallyDefaultValue(4, for: 3)
        persistedState.triggerShortPress(keyID: 3)
        persistedState.clearFunction(keyID: 7)
        let store = FakeDeckConfigurationStore(loadedState: persistedState)
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: store
        )

        model.checkOnLaunch()

        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        #expect(model.interactionState.tallyDefaultValue(for: 3) == 4)
        #expect(model.interactionState.tallyValue(for: 3) == 5)
        #expect(model.interactionState.configuration(for: 7)?.function == DeckKeyFunction.none)
        #expect(syncer.sentDisplays.first?[2].title == "5")
        #expect(syncer.sentDisplays.first?[2].subtitle == "默认 4")
        #expect(syncer.sentDisplays.first?[6].title == "")
        #expect(syncer.sentDisplays.first?[6].subtitle == "")
    }

    @MainActor
    @Test func launchSyncDoesNotBlockUIAndFinishesLater() async throws {
        let syncer = FakeH200DeckSyncer(packageDelayNanoseconds: 120_000_000)
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore()
        )

        let startedAt = DispatchTime.now().uptimeNanoseconds
        model.checkOnLaunch()
        model.selectKey(keyID: 8)
        let elapsedNanoseconds = DispatchTime.now().uptimeNanoseconds - startedAt

        #expect(elapsedNanoseconds < 60_000_000)
        #expect(model.interactionState.selectedKeyID == 8)
        #expect(syncer.sentDisplays.isEmpty)

        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        #expect(model.syncSummary?.elapsedNanoseconds ?? 0 >= 120_000_000)
    }

    @MainActor
    @Test func displayChangesDuringStartupSyncTriggerFullResyncAfterStartup() async throws {
        let syncer = FakeH200DeckSyncer(packageDelayNanoseconds: 80_000_000)
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore()
        )

        model.checkOnLaunch()
        model.selectKey(keyID: 7)
        model.setSelectedTallyDefaultValue(9)

        try await Self.waitUntil {
            syncer.sentDisplays.count == 2
        }
        #expect(syncer.sentDisplays[0][6].title == "0")
        #expect(syncer.sentDisplays[1][6].title == "9")
        #expect(syncer.partialDisplays.isEmpty)
    }

    @MainActor
    @Test func configurationChangesArePersisted() async throws {
        let store = FakeDeckConfigurationStore()
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: store
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        model.selectKey(keyID: 2)
        model.setSelectedTallyDefaultValue(3)
        syncer.emitInput(H200InputEvent(state: 1, index: 1, type: .button, action: .press))
        try await Task.sleep(nanoseconds: 50_000_000)
        syncer.emitInput(H200InputEvent(state: 0, index: 1, type: .button, action: .release))
        try await Task.sleep(nanoseconds: 50_000_000)
        model.clearKeyFunction(keyID: 2)

        #expect(store.savedStates.count == 3)
        #expect(store.savedStates[0].tallyDefaultValue(for: 2) == 3)
        #expect(store.savedStates[1].tallyValue(for: 2) == 4)
        #expect(store.savedStates[2].configuration(for: 2)?.function == DeckKeyFunction.none)
    }

    @MainActor
    @Test func swappingSquareKeysPersistsAndSendsOnlyChangedDisplays() async throws {
        let layout = DeckGridLayout.h200Prototype
        var loadedState = DeckGridInteractionState(layout: layout)
        loadedState.assign(.openFolder, to: 1)
        loadedState.setFolderConfiguration(Self.folderConfiguration(path: "/Users/ibobby/Documents"), for: 1)
        loadedState.assign(.connectSMBServer, to: 2)
        loadedState.setSMBServerAddress("nas.local/media", for: 2)
        loadedState.setSMBServerName("NAS", for: 2)
        loadedState.select(keyID: 1)
        let store = FakeDeckConfigurationStore(loadedState: loadedState)
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: store
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }

        model.swapSquareKeyConfigurations(sourceKeyID: 1, targetKeyID: 2)

        try await Self.waitUntil {
            syncer.partialDisplays.count == 1
        }
        let displays = try #require(syncer.partialDisplays.last)
        #expect(displays.map(\.id) == [1, 2])
        #expect(displays[0].title == "NAS")
        #expect(displays[0].subtitle == "nas.local/media")
        #expect(displays[0].smbServerButtonContent?.displayName == "NAS")
        #expect(displays[1].title == "Documents")
        #expect(displays[1].subtitle == "/Users/ibobby/Documents")
        #expect(displays[1].folderButtonContent?.displayName == "Documents")
        #expect(model.interactionState.selectedKeyID == 2)
        #expect(store.savedStates.count == 1)
        #expect(store.savedStates.last?.configuration(for: 1)?.function == .connectSMBServer)
        #expect(store.savedStates.last?.configuration(for: 2)?.function == .openFolder)
    }

    @MainActor
    @Test func wideKeyBuiltInDisplayModesClearFunctionAndSendPartialPackage() async throws {
        let store = FakeDeckConfigurationStore()
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: store
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        model.setKeyDisplayMode(.systemStatus, for: 14)
        try await Self.waitUntil {
            syncer.smallWindowModes == [.stats]
        }
        model.setKeyDisplayMode(.clock, for: 14)
        try await Self.waitUntil {
            syncer.smallWindowModes == [.stats, .dial]
        }

        #expect(syncer.sentDisplays.count == 1)
        #expect(syncer.partialDisplays.count == 2)
        #expect(syncer.partialDisplays[0].map(\.id) == [14])
        #expect(syncer.partialDisplays[0].first?.displayMode == .systemStatus)
        #expect(syncer.partialDisplays[1].first?.displayMode == .clock)
        #expect(model.interactionState.configuration(for: 14)?.function == DeckKeyFunction.none)
        #expect(model.interactionState.configuration(for: 14)?.displayMode == .clock)
        #expect(store.savedStates.first?.configuration(for: 14)?.function == DeckKeyFunction.none)
        #expect(store.savedStates.last?.configuration(for: 14)?.displayMode == .clock)
    }

    @MainActor
    @Test func returningWideKeyToFunctionModeSendsPartialPackage() async throws {
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore()
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        model.setKeyDisplayMode(.systemStatus, for: 14)
        try await Self.waitUntil {
            syncer.smallWindowModes == [.stats]
        }
        model.setKeyDisplayMode(.function, for: 14)
        try await Self.waitUntil {
            syncer.partialDisplays.count == 2
        }

        #expect(model.interactionState.configuration(for: 14)?.function == DeckKeyFunction.none)
        #expect(syncer.partialDisplays.last?.map(\.id) == [14])
        #expect(syncer.partialDisplays.last?.first?.displayMode == .function)
    }

    @MainActor
    @Test func uiSelectionChangesParameterTargetWithoutSyncingDisplays() async throws {
        let connectedIdentity = Self.protocolInterfaceIdentity()
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(connectedIdentity)]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore()
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        model.selectKey(keyID: 8)

        #expect(model.interactionState.selectedKeyID == 8)
        #expect(syncer.sentDisplays.count == 1)
    }

    @MainActor
    @Test func clearingFunctionSyncsEmptyDisplayAndIgnoresPhysicalInput() async throws {
        let connectedIdentity = Self.protocolInterfaceIdentity()
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(connectedIdentity)]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore()
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        model.clearKeyFunction(keyID: 7)
        syncer.emitInput(H200InputEvent(state: 1, index: 6, type: .button, action: .press))
        try await Task.sleep(nanoseconds: 50_000_000)
        syncer.emitInput(H200InputEvent(state: 0, index: 6, type: .button, action: .release))
        try await Task.sleep(nanoseconds: 50_000_000)
        try await Self.waitUntil {
            syncer.partialDisplays.count == 1
        }

        #expect(model.interactionState.selectedKeyID == 7)
        #expect(model.interactionState.configuration(for: 7)?.function == DeckKeyFunction.none)
        #expect(model.interactionState.tallyValue(for: 7) == 0)
        #expect(model.interactionState.pressedKeyIDs.isEmpty)
        #expect(syncer.sentDisplays.count == 1)
        #expect(syncer.partialDisplays.count == 1)
        #expect(syncer.partialDisplays.last?.map(\.id) == [7])
        #expect(syncer.partialDisplays.last?.first?.title == "")
        #expect(syncer.partialDisplays.last?.first?.subtitle == "")
    }

    @MainActor
    @Test func selectingTheSameSidebarFunctionAgainClearsIt() async throws {
        let connectedIdentity = Self.protocolInterfaceIdentity()
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(connectedIdentity)]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore()
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        model.selectKey(keyID: 7)
        model.assignSelectedFunction(.tally)
        try await Self.waitUntil {
            syncer.partialDisplays.count == 1
        }

        #expect(model.interactionState.configuration(for: 7)?.function == DeckKeyFunction.none)
        #expect(syncer.sentDisplays.count == 1)
        #expect(syncer.partialDisplays.count == 1)
        #expect(syncer.partialDisplays.last?.map(\.id) == [7])
        #expect(syncer.partialDisplays.last?.first?.title == "")
        #expect(syncer.partialDisplays.last?.first?.subtitle == "")
    }

    @MainActor
    @Test func sidebarFunctionCanRestoreClearedKey() async throws {
        let connectedIdentity = Self.protocolInterfaceIdentity()
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(connectedIdentity)]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore()
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        model.clearKeyFunction(keyID: 7)
        model.assignSelectedFunction(.tally)

        try await Self.waitUntil {
            syncer.partialDisplays.count == 2
        }
        #expect(model.interactionState.selectedKeyID == 7)
        #expect(model.interactionState.configuration(for: 7)?.function == .tally)
        #expect(syncer.sentDisplays.count == 1)
        #expect(syncer.partialDisplays.count == 2)
        #expect(syncer.partialDisplays.last?.map(\.id) == [7])
        #expect(syncer.partialDisplays.last?.first?.title == "0")
        #expect(syncer.partialDisplays.last?.first?.subtitle == "默认 0")
    }

    @MainActor
    @Test func selectingOpenFolderFunctionSyncsAndPersistsFolderPath() async throws {
        let syncer = FakeH200DeckSyncer()
        let store = FakeDeckConfigurationStore()
        let backgroundPNGData = Self.solidColorIconPNGData(color: .systemGreen)
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: store,
            folderOpener: FakeFinderFolderOpener()
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        model.selectKey(keyID: 4)
        model.assignSelectedFunction(.openFolder)
        model.setSelectedFolderConfiguration(Self.folderConfiguration(path: "/Users/ibobby/Documents"))
        model.setSelectedFolderName("下载")
        model.setFolderBackgroundPNGData(backgroundPNGData, for: 4)

        try await Self.waitUntil {
            syncer.partialDisplays.count == 4
        }
        #expect(model.interactionState.configuration(for: 4)?.function == DeckKeyFunction.openFolder)
        #expect(model.interactionState.folderPath(for: 4) == "/Users/ibobby/Documents")
        #expect(syncer.sentDisplays.count == 1)
        #expect(syncer.partialDisplays.count == 4)
        #expect(syncer.partialDisplays.last?.map(\.id) == [4])
        #expect(syncer.partialDisplays.last?.first?.title == "下载")
        #expect(syncer.partialDisplays.last?.first?.subtitle == "/Users/ibobby/Documents")
        #expect(syncer.partialDisplays.last?.first?.folderButtonContent?.displayName == "下载")
        #expect(syncer.partialDisplays.last?.first?.folderButtonContent?.backgroundPNGData == backgroundPNGData)
        #expect(store.savedStates.last?.folderPath(for: 4) == "/Users/ibobby/Documents")
        #expect(store.savedStates.last?.configuration(for: 4)?.buttonVisualConfiguration?.name == "下载")
        #expect(store.savedStates.last?.configuration(for: 4)?.buttonVisualConfiguration?.backgroundPNGData == backgroundPNGData)
    }

    @MainActor
    @Test func selectingOpenFileFunctionSyncsAndPersistsFilePath() async throws {
        let syncer = FakeH200DeckSyncer()
        let store = FakeDeckConfigurationStore()
        let iconPNGData = Self.solidColorIconPNGData(color: .systemRed)
        let blurredIconPNGData = Self.solidColorIconPNGData(color: .systemBlue)
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: store,
            fileOpener: FakeFinderFileOpener()
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        model.selectKey(keyID: 4)
        model.assignSelectedFunction(.openFile)
        model.setSelectedFileConfiguration(Self.fileConfiguration(
            path: "/Users/ibobby/Documents/report.pdf",
            iconPNGData: iconPNGData,
            blurredIconPNGData: blurredIconPNGData
        ))
        model.setSelectedFileName("报告")

        try await Self.waitUntil {
            syncer.partialDisplays.count == 3
        }
        #expect(model.interactionState.configuration(for: 4)?.function == DeckKeyFunction.openFile)
        #expect(model.interactionState.filePath(for: 4) == "/Users/ibobby/Documents/report.pdf")
        #expect(syncer.sentDisplays.count == 1)
        #expect(syncer.partialDisplays.count == 3)
        #expect(syncer.partialDisplays.last?.map(\.id) == [4])
        #expect(syncer.partialDisplays.last?.first?.title == "报告")
        #expect(syncer.partialDisplays.last?.first?.subtitle == "/Users/ibobby/Documents/report.pdf")
        #expect(syncer.partialDisplays.last?.first?.fileButtonContent?.displayName == "报告")
        #expect(syncer.partialDisplays.last?.first?.fileButtonContent?.backgroundPNGData == iconPNGData)
        #expect(store.savedStates.last?.filePath(for: 4) == "/Users/ibobby/Documents/report.pdf")
        #expect(store.savedStates.last?.configuration(for: 4)?.buttonVisualConfiguration?.name == "报告")
        #expect(store.savedStates.last?.openFileConfiguration(for: 4).iconPNGData == iconPNGData)
        #expect(store.savedStates.last?.openFileConfiguration(for: 4).blurredIconPNGData == blurredIconPNGData)

        model.setFileIconBlurEnabled(true, for: 4)

        try await Self.waitUntil {
            syncer.partialDisplays.count == 4
        }
        #expect(syncer.partialDisplays.last?.first?.fileButtonContent?.backgroundPNGData == blurredIconPNGData)
        #expect(store.savedStates.last?.configuration(for: 4)?.buttonVisualConfiguration?.usesBlurredBackground == true)
    }

    @MainActor
    @Test func selectingConnectSMBServerFunctionSyncsAndPersistsNameAndAddress() async throws {
        let syncer = FakeH200DeckSyncer()
        let store = FakeDeckConfigurationStore()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: store,
            smbServerConnector: FakeSMBServerConnector()
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        model.selectKey(keyID: 4)
        model.assignSelectedFunction(.connectSMBServer)
        model.setSelectedSMBServerAddress("smb://nas.local/media")
        model.setSelectedSMBServerName("NAS")

        try await Self.waitUntil {
            syncer.partialDisplays.count == 3
        }
        #expect(model.interactionState.configuration(for: 4)?.function == DeckKeyFunction.connectSMBServer)
        #expect(model.interactionState.smbServerAddress(for: 4) == "nas.local/media")
        #expect(model.interactionState.configuration(for: 4)?.buttonVisualConfiguration?.name == "NAS")
        #expect(syncer.sentDisplays.count == 1)
        #expect(syncer.partialDisplays.count == 3)
        #expect(syncer.partialDisplays.last?.map(\.id) == [4])
        #expect(syncer.partialDisplays.last?.first?.title == "NAS")
        #expect(syncer.partialDisplays.last?.first?.subtitle == "nas.local/media")
        #expect(syncer.partialDisplays.last?.first?.smbServerButtonContent?.displayName == "NAS")
        #expect(store.savedStates.last?.smbServerAddress(for: 4) == "nas.local/media")
        #expect(store.savedStates.last?.configuration(for: 4)?.buttonVisualConfiguration?.name == "NAS")
    }

    @MainActor
    @Test func previewingDisplayNamesSyncsTrimmedDisplayWithoutPersisting() async throws {
        let syncer = FakeH200DeckSyncer()
        let store = FakeDeckConfigurationStore()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: store,
            folderOpener: FakeFinderFolderOpener(),
            fileOpener: FakeFinderFileOpener(),
            smbServerConnector: FakeSMBServerConnector()
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        model.selectKey(keyID: 4)
        model.assignSelectedFunction(.openFolder)
        model.setSelectedFolderConfiguration(Self.folderConfiguration(path: "/Users/ibobby/Documents"))
        try await Self.waitUntil {
            syncer.partialDisplays.count == 2
        }

        let folderSavedStateCount = store.savedStates.count
        let folderPartialDisplayCount = syncer.partialDisplays.count
        model.previewFolderName(" 资料 ", for: 4)

        try await Self.waitUntil {
            syncer.partialDisplays.count == folderPartialDisplayCount + 1
        }
        #expect(store.savedStates.count == folderSavedStateCount)
        #expect(model.interactionState.configuration(for: 4)?.buttonVisualConfiguration?.name == "资料")
        #expect(syncer.partialDisplays.last?.first?.title == "资料")

        model.selectKey(keyID: 6)
        model.assignSelectedFunction(.openFile)
        model.setSelectedFileConfiguration(Self.fileConfiguration(path: "/Users/ibobby/Documents/report.pdf"))
        try await Self.waitUntil {
            syncer.partialDisplays.count == folderPartialDisplayCount + 3
        }

        let fileSavedStateCount = store.savedStates.count
        let filePartialDisplayCount = syncer.partialDisplays.count
        model.previewFileName(" 报告 ", for: 6)

        try await Self.waitUntil {
            syncer.partialDisplays.count == filePartialDisplayCount + 1
        }
        #expect(store.savedStates.count == fileSavedStateCount)
        #expect(model.interactionState.configuration(for: 6)?.buttonVisualConfiguration?.name == "报告")
        #expect(syncer.partialDisplays.last?.first?.title == "报告")

        model.selectKey(keyID: 5)
        model.assignSelectedFunction(.connectSMBServer)
        model.setSelectedSMBServerAddress("nas.local/media")
        try await Self.waitUntil {
            syncer.partialDisplays.count == filePartialDisplayCount + 3
        }

        let smbSavedStateCount = store.savedStates.count
        let smbPartialDisplayCount = syncer.partialDisplays.count
        model.previewSMBServerName(" NAS ", for: 5)

        try await Self.waitUntil {
            syncer.partialDisplays.count == smbPartialDisplayCount + 1
        }
        #expect(store.savedStates.count == smbSavedStateCount)
        #expect(model.interactionState.configuration(for: 5)?.buttonVisualConfiguration?.name == "NAS")
        #expect(syncer.partialDisplays.last?.first?.title == "NAS")
    }

    @MainActor
    @Test func launchImmediatelyRefreshesConfiguredSub2APIKey() async throws {
        let item = Self.sub2APICapacityItem(groupID: 1215, groupName: "PLU", availableConcurrency: 3078)
        let fetcher = FakeSub2APIFetcher(results: [.success(item: item)])
        let layout = DeckGridLayout.h200Prototype
        var loadedState = DeckGridInteractionState(layout: layout)
        loadedState.assign(.sub2API, to: 3)
        loadedState.setSub2APIBaseURL("api.example.com", for: 3)
        loadedState.setSub2APITargetGroupID(1215, for: 3)
        loadedState.setSub2APIBearerKey("token", for: 3)
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore(loadedState: loadedState),
            sub2APIFetcher: fetcher
        )

        model.checkOnLaunch()

        try await Self.waitUntil {
            fetcher.requests.count == 1
                && model.interactionState.configuration(for: 3)?.sub2API.lastResult == .success(item: item)
                && Self.hasSyncedDisplayTitle("3078", for: 3, syncer: syncer)
        }

        #expect(fetcher.requests == [
            FakeSub2APIFetcher.Request(baseURL: "api.example.com", targetGroupID: 1215, bearerKey: "token"),
        ])
    }

    @MainActor
    @Test func topBrightnessSliderSendsLatestValueWithoutPilingUp() async throws {
        let syncer = FakeH200DeckSyncer(brightnessDelayNanoseconds: 100_000_000)
        let store = FakeDeckConfigurationStore()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: store,
            folderOpener: FakeFinderFolderOpener()
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        let sentDisplayCount = syncer.sentDisplays.count

        model.previewBrightnessPercent(10)
        model.previewBrightnessPercent(20)
        model.previewBrightnessPercent(30)
        model.commitBrightnessPercent(30)

        #expect(model.brightnessPercent == 30)
        #expect(store.savedBrightnessPercents == [30])
        try await Self.waitUntil {
            syncer.brightnessPercents == [10, 30]
                && syncer.sentDisplays.count == sentDisplayCount
        }
    }

    @MainActor
    @Test func topBrightnessSliderLoadsPersistedValue() {
        let store = FakeDeckConfigurationStore(loadedBrightnessPercent: 65)
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.notConnected]),
            syncer: FakeH200DeckSyncer(),
            configurationStore: store,
            folderOpener: FakeFinderFolderOpener()
        )

        #expect(model.brightnessPercent == 65)
    }

    @MainActor
    @Test func buttonVisualDimmingChangePersistsAndResyncsDisplay() async throws {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)
        state.assign(.openFolder, to: 2)
        state.setFolderConfiguration(Self.folderConfiguration(path: "/Users/ibobby/Documents"), for: 2)
        let syncer = FakeH200DeckSyncer()
        let store = FakeDeckConfigurationStore(loadedState: state)
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: store,
            folderOpener: FakeFinderFolderOpener()
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        #expect(syncer.sentDisplays.last?.first(where: { $0.id == 2 })?.folderButtonContent?.dimsBackground == true)

        model.setButtonVisualDimmingEnabled(false, for: 2)

        try await Self.waitUntil {
            syncer.partialDisplays.count == 1
        }
        #expect(store.savedStates.last?.configuration(for: 2)?.buttonVisualConfiguration?.dimsBackground == false)
        #expect(syncer.partialDisplays.last?.first?.folderButtonContent?.dimsBackground == false)
    }

    @MainActor
    @Test func successfulLaunchSendsPersistedBrightnessAfterStartup() async throws {
        let store = FakeDeckConfigurationStore(loadedBrightnessPercent: 65)
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: store,
            folderOpener: FakeFinderFolderOpener()
        )

        model.checkOnLaunch()

        try await Self.waitUntil {
            syncer.brightnessPercents == [65]
        }
        #expect(model.brightnessPercent == 65)
        #expect(syncer.sentDisplays.count == 1)
    }

    @MainActor
    @Test func topBrightnessSliderFailureShowsAlert() async throws {
        let code = Self.exclusiveAccessReturnCode()
        let syncer = FakeH200DeckSyncer(brightnessFailures: [.communicationPortOccupied(code)])
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore(),
            folderOpener: FakeFinderFolderOpener()
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        model.commitBrightnessPercent(25)
        try await Self.waitUntil {
            model.alert?.title == "H200 通信端口被占用"
        }

        #expect(syncer.brightnessPercents == [25])
        #expect(model.alert?.message.contains("有其他应用正在占用 H200 通信端口") == true)
    }

    @MainActor
    @Test func brightnessAdjustmentRequiresRunningAdjuster() {
        let adjuster = FakeBrightnessAdjuster()

        BrightnessAdjustmentRuntime.shared.register(adjuster)
        BrightnessAdjustmentRuntime.shared.unregister(adjuster)

        #expect(BrightnessAdjustmentRuntime.shared.adjustBrightness(to: 25) == .appNotRunning)
        #expect(adjuster.appliedPercents.isEmpty)
    }

    @MainActor
    @Test func brightnessAdjustmentRequiresConnectedAndSyncedModel() {
        let store = FakeDeckConfigurationStore()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.notConnected]),
            syncer: FakeH200DeckSyncer(),
            configurationStore: store,
            folderOpener: FakeFinderFolderOpener()
        )
        BrightnessAdjustmentRuntime.shared.register(model)
        defer {
            BrightnessAdjustmentRuntime.shared.unregister(model)
        }

        #expect(BrightnessAdjustmentRuntime.shared.adjustBrightness(to: 25) == .deviceNotReady)
        #expect(model.brightnessPercent == DeckBrightnessConfiguration.defaultPercent)
        #expect(store.savedBrightnessPercents.isEmpty)
    }

    @MainActor
    @Test func brightnessAdjustmentSendsWithoutPersisting() async throws {
        let store = FakeDeckConfigurationStore()
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: store,
            folderOpener: FakeFinderFolderOpener()
        )
        BrightnessAdjustmentRuntime.shared.register(model)
        defer {
            BrightnessAdjustmentRuntime.shared.unregister(model)
        }

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        let result = BrightnessAdjustmentRuntime.shared.adjustBrightness(to: 35)

        #expect(result == .sent(35))
        #expect(model.brightnessPercent == 35)
        #expect(store.savedBrightnessPercents.isEmpty)
        try await Self.waitUntil {
            syncer.brightnessPercents == [35]
        }
    }

    @MainActor
    @Test func brightnessZeroPausesInternalRefreshAndRestoringBrightnessRefetches() async throws {
        let sub2APIItem = Self.sub2APICapacityItem(groupID: 1215, groupName: "PLU", availableConcurrency: 3078)
        let gameStatus = Self.mihoyoStatus(game: .genshin, currentStamina: 180, maxStamina: 200)
        let fetcher = FakeSub2APIFetcher(defaultResult: .success(item: sub2APIItem))
        let mihoyoService = FakeMihoyoGameService(defaultFetchResult: .success(gameStatus))
        let layout = DeckGridLayout.h200Prototype
        var loadedState = DeckGridInteractionState(layout: layout)
        loadedState.assign(.sub2API, to: 3)
        loadedState.setSub2APIBaseURL("api.example.com", for: 3)
        loadedState.setSub2APITargetGroupID(1215, for: 3)
        loadedState.setSub2APIBearerKey("token", for: 3)
        loadedState.setSub2APIRefreshInterval(5, for: 3)
        loadedState.assign(.genshinStatus, to: 4)
        loadedState.setMihoyoGameRefreshIntervalMinutes(1, for: 4)
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore(loadedState: loadedState),
            sub2APIFetcher: fetcher,
            mihoyoGameService: mihoyoService,
            mihoyoSessionStore: FakeMihoyoSessionStore(loadedSession: Self.mihoyoSession()),
            sub2APIRefreshSecondDuration: 0.02,
            mihoyoGameRefreshMinuteDuration: 0.1
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            fetcher.requests.count >= 1 && mihoyoService.fetchRequests.count >= 1
        }

        model.commitBrightnessPercent(0)
        try await Self.waitUntil {
            syncer.internalRefreshPausedValues.contains(true)
                && syncer.brightnessPercents.contains(0)
        }
        let pausedSub2APIRequestCount = fetcher.requests.count
        let pausedGameRequestCount = mihoyoService.fetchRequests.count
        try await Task.sleep(nanoseconds: 160_000_000)

        #expect(fetcher.requests.count == pausedSub2APIRequestCount)
        #expect(mihoyoService.fetchRequests.count == pausedGameRequestCount)

        model.commitBrightnessPercent(20)

        try await Self.waitUntil {
            syncer.internalRefreshPausedValues.contains(false)
                && fetcher.requests.count > pausedSub2APIRequestCount
                && mihoyoService.fetchRequests.count > pausedGameRequestCount
        }
    }

    @MainActor
    @Test func shortcutsBrightnessZeroPausesInternalRefreshWithoutPersisting() async throws {
        let store = FakeDeckConfigurationStore()
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: store,
            folderOpener: FakeFinderFolderOpener()
        )
        BrightnessAdjustmentRuntime.shared.register(model)
        defer {
            BrightnessAdjustmentRuntime.shared.unregister(model)
        }

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }

        let result = BrightnessAdjustmentRuntime.shared.adjustBrightness(to: 0)

        #expect(result == .sent(0))
        #expect(model.brightnessPercent == 0)
        #expect(store.savedBrightnessPercents.isEmpty)
        try await Self.waitUntil {
            syncer.brightnessPercents == [0]
                && syncer.internalRefreshPausedValues.contains(true)
        }
    }

    @Test func fakeDeckSyncerReturnsElapsedTimeAfterBlockingPackageSend() {
        let syncer = FakeH200DeckSyncer(packageDelayNanoseconds: 25_000_000)
        let layout = DeckGridLayout.h200Prototype
        let display = DeckGridInteractionState(layout: layout).display(for: layout.keys[0])

        let result = syncer.sendStartupPackage(displays: [display])

        #expect(syncer.sentDisplays.count == 1)
        #expect(result.elapsedNanoseconds >= 25_000_000)
        #expect(result.elapsedMilliseconds >= 25)
    }

    @MainActor
    @Test func physicalButtonPageFolderNavigatesAndSendsFullPagePackage() async throws {
        let syncer = FakeH200DeckSyncer()
        let store = FakeDeckConfigurationStore()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: store
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        model.selectKey(keyID: 2)
        model.assignSelectedFunction(.pageFolder)
        try await Self.waitUntil {
            syncer.partialDisplays.count == 1
        }

        syncer.emitInput(H200InputEvent(state: 1, index: 1, type: .button, action: .press))
        syncer.emitInput(H200InputEvent(state: 0, index: 1, type: .button, action: .release))

        try await Self.waitUntil {
            syncer.sentDisplays.count == 2
        }
        #expect(model.interactionState.currentPageDepth == 1)
        #expect(model.interactionState.configuration(for: 1)?.function == .pageBack)
        #expect(syncer.sentDisplays.last?.count == 14)
        #expect(syncer.sentDisplays.last?.first?.pageBackButtonContent?.displayName == "返回")
        #expect(store.savedStates.last?.currentPageID == DeckGridInteractionState.rootPageID)
    }

    @MainActor
    @Test func physicalButtonPageBackReturnsAndSendsFullPagePackage() async throws {
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore()
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        model.selectKey(keyID: 2)
        model.assignSelectedFunction(.pageFolder)
        try await Self.waitUntil {
            syncer.partialDisplays.count == 1
        }
        model.navigateKey(keyID: 2)
        try await Self.waitUntil {
            syncer.sentDisplays.count == 2
        }

        syncer.emitInput(H200InputEvent(state: 1, index: 0, type: .button, action: .press))
        syncer.emitInput(H200InputEvent(state: 0, index: 0, type: .button, action: .release))

        try await Self.waitUntil {
            syncer.sentDisplays.count == 3
        }
        #expect(model.interactionState.currentPageID == DeckGridInteractionState.rootPageID)
        #expect(syncer.sentDisplays.last?.count == 14)
        #expect(syncer.sentDisplays.last?[1].pageFolderButtonContent?.displayName == "文件夹")
    }

    @MainActor
    @Test func physicalButtonShortPressIncrementsTallyWithoutChangingUISelection() async throws {
        let connectedIdentity = Self.protocolInterfaceIdentity()
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(connectedIdentity)]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore()
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        model.selectKey(keyID: 3)
        syncer.emitInput(H200InputEvent(state: 1, index: 6, type: .button, action: .press))
        try await Task.sleep(nanoseconds: 50_000_000)
        syncer.emitInput(H200InputEvent(state: 0, index: 6, type: .button, action: .release))
        try await Task.sleep(nanoseconds: 50_000_000)
        syncer.emitInput(H200InputEvent(state: 1, index: 6, type: .button, action: .press))
        try await Task.sleep(nanoseconds: 50_000_000)
        syncer.emitInput(H200InputEvent(state: 0, index: 6, type: .button, action: .release))
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(model.interactionState.selectedKeyID == 3)
        #expect(model.interactionState.tallyValue(for: 7) == 2)
    }

    @MainActor
    @Test func physicalButtonShortPressOpensConfiguredFolderWithoutSyncingDisplay() async throws {
        let opener = FakeFinderFolderOpener()
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore(),
            folderOpener: opener
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        model.selectKey(keyID: 4)
        model.assignSelectedFunction(.openFolder)
        model.setSelectedFolderConfiguration(Self.folderConfiguration(path: "/Users/ibobby/Documents"))
        let sentDisplayCount = syncer.sentDisplays.count
        syncer.emitInput(H200InputEvent(state: 1, index: 3, type: .button, action: .press))
        try await Task.sleep(nanoseconds: 50_000_000)
        syncer.emitInput(H200InputEvent(state: 0, index: 3, type: .button, action: .release))
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(opener.openedPaths == ["/Users/ibobby/Documents"])
        #expect(syncer.sentDisplays.count == sentDisplayCount)
        #expect(model.interactionState.selectedKeyID == 4)
    }

    @MainActor
    @Test func physicalButtonOpenFolderPersistsRefreshedBookmarkWithoutSyncingDisplay() async throws {
        let opener = FakeFinderFolderOpener()
        let refreshedBookmarkData = try #require("refreshed-bookmark".data(using: .utf8))
        opener.result = .opened(refreshedConfiguration: Self.folderConfiguration(
            path: "/Users/ibobby/Documents",
            bookmarkData: refreshedBookmarkData
        ))
        let syncer = FakeH200DeckSyncer()
        let store = FakeDeckConfigurationStore()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: store,
            folderOpener: opener
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        let backgroundPNGData = Self.solidColorIconPNGData(color: .systemBlue)
        model.selectKey(keyID: 4)
        model.assignSelectedFunction(.openFolder)
        model.setSelectedFolderConfiguration(Self.folderConfiguration(
            path: "/Users/ibobby/Documents",
            bookmarkData: Data("old-bookmark".utf8),
            backgroundPNGData: backgroundPNGData
        ))
        try await Self.waitUntil {
            syncer.partialDisplays.count >= 2
        }
        let sentDisplayCount = syncer.sentDisplays.count
        let partialDisplayCount = syncer.partialDisplays.count
        syncer.emitInput(H200InputEvent(state: 1, index: 3, type: .button, action: .press))
        try await Task.sleep(nanoseconds: 50_000_000)
        syncer.emitInput(H200InputEvent(state: 0, index: 3, type: .button, action: .release))

        try await Self.waitUntil {
            store.savedStates.last?.openFolderConfiguration(for: 4).bookmarkData == refreshedBookmarkData
        }

        #expect(opener.openedPaths == ["/Users/ibobby/Documents"])
        #expect(model.interactionState.openFolderConfiguration(for: 4).bookmarkData == refreshedBookmarkData)
        #expect(model.interactionState.openFolderConfiguration(for: 4).backgroundPNGData == backgroundPNGData)
        #expect(store.savedStates.last?.openFolderConfiguration(for: 4).backgroundPNGData == backgroundPNGData)
        #expect(syncer.sentDisplays.count == sentDisplayCount)
        #expect(syncer.partialDisplays.count == partialDisplayCount)
        #expect(model.interactionState.selectedKeyID == 4)
    }

    @MainActor
    @Test func physicalButtonOpenFolderWithoutFolderDoesNothing() async throws {
        let opener = FakeFinderFolderOpener()
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore(),
            folderOpener: opener
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        model.selectKey(keyID: 4)
        model.assignSelectedFunction(.openFolder)
        syncer.emitInput(H200InputEvent(state: 1, index: 3, type: .button, action: .press))
        try await Task.sleep(nanoseconds: 50_000_000)
        syncer.emitInput(H200InputEvent(state: 0, index: 3, type: .button, action: .release))
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(opener.openedPaths.isEmpty)
    }

    @MainActor
    @Test func physicalButtonOpenFolderWithLegacyPathOnlyConfigurationDoesNothing() async throws {
        let opener = FakeFinderFolderOpener()
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore(),
            folderOpener: opener
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        model.selectKey(keyID: 4)
        model.assignSelectedFunction(.openFolder)
        model.setSelectedFolderConfiguration(Self.folderConfiguration(
            path: "/Users/ibobby/Documents",
            bookmarkData: nil
        ))
        syncer.emitInput(H200InputEvent(state: 1, index: 3, type: .button, action: .press))
        try await Task.sleep(nanoseconds: 50_000_000)
        syncer.emitInput(H200InputEvent(state: 0, index: 3, type: .button, action: .release))
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(opener.openedPaths.isEmpty)
        #expect(opener.openedConfigurations.isEmpty)
    }

    @MainActor
    @Test func physicalButtonShortPressOpensConfiguredFileWithoutSyncingDisplay() async throws {
        let opener = FakeFinderFileOpener()
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore(),
            fileOpener: opener
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        model.selectKey(keyID: 4)
        model.assignSelectedFunction(.openFile)
        model.setSelectedFileConfiguration(Self.fileConfiguration(path: "/Users/ibobby/Documents/report.pdf"))
        let sentDisplayCount = syncer.sentDisplays.count
        syncer.emitInput(H200InputEvent(state: 1, index: 3, type: .button, action: .press))
        try await Task.sleep(nanoseconds: 50_000_000)
        syncer.emitInput(H200InputEvent(state: 0, index: 3, type: .button, action: .release))
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(opener.openedPaths == ["/Users/ibobby/Documents/report.pdf"])
        #expect(syncer.sentDisplays.count == sentDisplayCount)
        #expect(model.interactionState.selectedKeyID == 4)
    }

    @MainActor
    @Test func physicalButtonOpenFilePersistsRefreshedBookmarkWithoutSyncingDisplay() async throws {
        let opener = FakeFinderFileOpener()
        let refreshedBookmarkData = try #require("refreshed-bookmark".data(using: .utf8))
        let iconPNGData = Self.solidColorIconPNGData(color: .systemRed)
        let blurredIconPNGData = Self.solidColorIconPNGData(color: .systemBlue)
        opener.result = .opened(refreshedConfiguration: Self.fileConfiguration(
            path: "/Users/ibobby/Documents/report.pdf",
            bookmarkData: refreshedBookmarkData
        ))
        let syncer = FakeH200DeckSyncer()
        let store = FakeDeckConfigurationStore()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: store,
            fileOpener: opener
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        model.selectKey(keyID: 4)
        model.assignSelectedFunction(.openFile)
        model.setSelectedFileConfiguration(Self.fileConfiguration(
            path: "/Users/ibobby/Documents/report.pdf",
            bookmarkData: Data("old-bookmark".utf8),
            iconPNGData: iconPNGData,
            blurredIconPNGData: blurredIconPNGData,
            usesBlurredIcon: true
        ))
        try await Self.waitUntil {
            syncer.partialDisplays.count >= 2
        }
        let sentDisplayCount = syncer.sentDisplays.count
        let partialDisplayCount = syncer.partialDisplays.count
        syncer.emitInput(H200InputEvent(state: 1, index: 3, type: .button, action: .press))
        try await Task.sleep(nanoseconds: 50_000_000)
        syncer.emitInput(H200InputEvent(state: 0, index: 3, type: .button, action: .release))

        try await Self.waitUntil {
            store.savedStates.last?.openFileConfiguration(for: 4).bookmarkData == refreshedBookmarkData
        }

        #expect(opener.openedPaths == ["/Users/ibobby/Documents/report.pdf"])
        #expect(model.interactionState.openFileConfiguration(for: 4).bookmarkData == refreshedBookmarkData)
        #expect(model.interactionState.openFileConfiguration(for: 4).iconPNGData == iconPNGData)
        #expect(model.interactionState.openFileConfiguration(for: 4).blurredIconPNGData == blurredIconPNGData)
        #expect(model.interactionState.openFileConfiguration(for: 4).usesBlurredIcon)
        #expect(store.savedStates.last?.openFileConfiguration(for: 4).iconPNGData == iconPNGData)
        #expect(store.savedStates.last?.openFileConfiguration(for: 4).blurredIconPNGData == blurredIconPNGData)
        #expect(syncer.sentDisplays.count == sentDisplayCount)
        #expect(syncer.partialDisplays.count == partialDisplayCount)
        #expect(model.interactionState.selectedKeyID == 4)
    }

    @MainActor
    @Test func physicalButtonOpenFileWithoutFileDoesNothing() async throws {
        let opener = FakeFinderFileOpener()
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore(),
            fileOpener: opener
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        model.selectKey(keyID: 4)
        model.assignSelectedFunction(.openFile)
        syncer.emitInput(H200InputEvent(state: 1, index: 3, type: .button, action: .press))
        try await Task.sleep(nanoseconds: 50_000_000)
        syncer.emitInput(H200InputEvent(state: 0, index: 3, type: .button, action: .release))
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(opener.openedPaths.isEmpty)
    }

    @MainActor
    @Test func physicalButtonOpenFileWithLegacyPathOnlyConfigurationDoesNothing() async throws {
        let opener = FakeFinderFileOpener()
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore(),
            fileOpener: opener
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        model.selectKey(keyID: 4)
        model.assignSelectedFunction(.openFile)
        model.setSelectedFileConfiguration(Self.fileConfiguration(
            path: "/Users/ibobby/Documents/report.pdf",
            bookmarkData: nil
        ))
        syncer.emitInput(H200InputEvent(state: 1, index: 3, type: .button, action: .press))
        try await Task.sleep(nanoseconds: 50_000_000)
        syncer.emitInput(H200InputEvent(state: 0, index: 3, type: .button, action: .release))
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(opener.openedPaths.isEmpty)
        #expect(opener.openedConfigurations.isEmpty)
    }

    @MainActor
    @Test func physicalButtonShortPressConnectsConfiguredSMBServerWithoutSyncingDisplay() async throws {
        let connector = FakeSMBServerConnector()
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore(),
            smbServerConnector: connector
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        model.selectKey(keyID: 4)
        model.assignSelectedFunction(.connectSMBServer)
        model.setSelectedSMBServerAddress("nas.local/media")
        model.setSelectedSMBServerName("NAS")
        let sentDisplayCount = syncer.sentDisplays.count
        syncer.emitInput(H200InputEvent(state: 1, index: 3, type: .button, action: .press))
        try await Task.sleep(nanoseconds: 50_000_000)
        syncer.emitInput(H200InputEvent(state: 0, index: 3, type: .button, action: .release))
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(connector.connectedAddresses == ["nas.local/media"])
        #expect(syncer.sentDisplays.count == sentDisplayCount)
        #expect(model.interactionState.selectedKeyID == 4)
    }

    @MainActor
    @Test func physicalButtonConnectSMBServerWithoutAddressDoesNothing() async throws {
        let connector = FakeSMBServerConnector()
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore(),
            smbServerConnector: connector
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        model.selectKey(keyID: 4)
        model.assignSelectedFunction(.connectSMBServer)
        syncer.emitInput(H200InputEvent(state: 1, index: 3, type: .button, action: .press))
        try await Task.sleep(nanoseconds: 50_000_000)
        syncer.emitInput(H200InputEvent(state: 0, index: 3, type: .button, action: .release))
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(connector.connectedAddresses.isEmpty)
    }

    @MainActor
    @Test func longPressOpenFolderIsNotSuppressedByTallyResetLogic() async throws {
        let opener = FakeFinderFolderOpener()
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore(),
            folderOpener: opener,
            longPressDurationNanoseconds: 10_000_000
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        model.selectKey(keyID: 4)
        model.assignSelectedFunction(.openFolder)
        model.setSelectedFolderConfiguration(Self.folderConfiguration(path: "/Users/ibobby/Documents"))
        syncer.emitInput(H200InputEvent(state: 1, index: 3, type: .button, action: .press))
        try await Task.sleep(nanoseconds: 30_000_000)
        syncer.emitInput(H200InputEvent(state: 0, index: 3, type: .button, action: .release))
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(opener.openedPaths == ["/Users/ibobby/Documents"])
    }

    @MainActor
    @Test func physicalReleaseAndEncoderEventsDoNotTriggerGridPresses() async throws {
        let connectedIdentity = Self.protocolInterfaceIdentity()
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(connectedIdentity)]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore()
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        syncer.emitInput(H200InputEvent(state: 1, index: 6, type: .button, action: .release))
        syncer.emitInput(H200InputEvent(state: 1, index: 17, type: .encoder, action: .press))
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(model.interactionState.selectedKeyID == 1)
        #expect(model.interactionState.configurations.values.allSatisfy { $0.tally.value == 0 })
    }

    @MainActor
    @Test func longPressResetsTallyToConfiguredDefault() async throws {
        let connectedIdentity = Self.protocolInterfaceIdentity()
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(connectedIdentity)]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore(),
            longPressDurationNanoseconds: 10_000_000
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        model.setSelectedTallyDefaultValue(5)
        syncer.emitInput(H200InputEvent(state: 1, index: 0, type: .button, action: .press))
        try await Task.sleep(nanoseconds: 5_000_000)
        syncer.emitInput(H200InputEvent(state: 0, index: 0, type: .button, action: .release))
        try await Task.sleep(nanoseconds: 20_000_000)
        syncer.emitInput(H200InputEvent(state: 1, index: 0, type: .button, action: .press))
        try await Task.sleep(nanoseconds: 30_000_000)
        syncer.emitInput(H200InputEvent(state: 0, index: 0, type: .button, action: .release))
        try await Task.sleep(nanoseconds: 20_000_000)

        #expect(model.interactionState.tallyDefaultValue(for: 1) == 5)
        #expect(model.interactionState.tallyValue(for: 1) == 5)
        #expect(model.interactionState.pressedKeyIDs.isEmpty)
    }

    @MainActor
    @Test func syncFailureShowsPackageNotSentAlert() async throws {
        let code = Self.exclusiveAccessReturnCode()
        let syncer = FakeH200DeckSyncer(results: [.failure(.communicationPortOccupied(code), elapsedNanoseconds: 0)])
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore()
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            model.alert?.title == "H200 通信端口被占用"
        }

        #expect(model.alert?.title == "H200 通信端口被占用")
        #expect(model.alert?.message.contains("按键包尚未发送") == true)
        #expect(model.syncSummary == nil)
    }

    @MainActor
    @Test func buttonPackageManifestMatchesDisplays() throws {
        let displays = DeckGridInteractionState(layout: .h200Prototype).displays(for: .h200Prototype)
        let builder = H200ButtonPackageBuilder(renderer: FakeH200ButtonIconRenderer())

        let package = try builder.buildPackage(displays: displays)
        let manifest = try JSONSerialization.jsonObject(with: package.manifestData) as? [String: Any] ?? [:]
        let firstEntry = manifest["0_0"] as? [String: Any]
        let firstViewParam = (firstEntry?["ViewParam"] as? [[String: Any]])?.first
        let smallEntry = manifest["3_2"] as? [String: Any]
        let smallViewParam = (smallEntry?["ViewParam"] as? [[String: Any]])?.first

        #expect(package.displayCount == 14)
        #expect(Array(package.payload.prefix(4)) == [0x50, 0x4b, 0x03, 0x04])
        #expect(H200PacketBuilder.isPayloadSafe(package.payload))
        #expect(manifest.count == 14)
        #expect(firstViewParam?["Icon"] as? String == "Images/key_1.png")
        #expect(firstViewParam?["Text"] as? String == "")
        #expect(smallEntry?["SmallViewMode"] as? Int == 2)
        #expect(smallViewParam?["Icon"] as? String == "Images/key_14.png")
    }

    @Test func buttonPackageManifestUsesSelectedSmallWindowMode() throws {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)
        state.setDisplayMode(.systemStatus, for: 14)
        let builder = H200ButtonPackageBuilder(renderer: FakeH200ButtonIconRenderer())

        let package = try builder.buildPackage(displays: state.displays(for: layout))
        let manifest = try JSONSerialization.jsonObject(with: package.manifestData) as? [String: Any] ?? [:]
        let smallEntry = manifest["3_2"] as? [String: Any]

        #expect(smallEntry?["SmallViewMode"] as? Int == H200SmallWindowMode.stats.rawValue)
    }

    @Test func buttonPackageUsesTransparentImageWhenClearingBuiltInSmallWindowMode() throws {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)
        state.setDisplayMode(.clock, for: 14)
        let display = state.display(for: layout.keys[13])
        let builder = H200ButtonPackageBuilder(renderer: FailingH200ButtonIconRenderer())

        let package = try builder.buildPackage(displays: [display])
        let manifest = try JSONSerialization.jsonObject(with: package.manifestData) as? [String: Any] ?? [:]
        let smallEntry = manifest["3_2"] as? [String: Any]

        #expect(package.displayCount == 1)
        #expect(smallEntry?["SmallViewMode"] as? Int == H200SmallWindowMode.dial.rawValue)
        #expect(H200PacketBuilder.isPayloadSafe(package.payload))
    }

    @Test func realButtonPackageBuilderCreatesSafePayload() throws {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)
        state.triggerShortPress(keyID: 7)
        state.triggerShortPress(keyID: 7)
        state.setTallyDefaultValue(12, for: 14)

        let package = try H200ButtonPackageBuilder().buildPackage(displays: state.displays(for: layout))

        #expect(package.displayCount == 14)
        #expect(H200PacketBuilder.isPayloadSafe(package.payload))
    }

    @Test func realIconRendererCreatesPNGForWideDisplay() throws {
        let display = DeckGridInteractionState(layout: .h200Prototype)
            .displays(for: .h200Prototype)
            .last!

        let png = try H200ButtonIconRenderer().pngData(for: display)

        #expect(Array(png.prefix(4)) == [0x89, 0x50, 0x4e, 0x47])
        #expect(!png.isEmpty)
    }

    @Test func autoSizedSingleLineTextFitsAllowedWidthAndHeight() {
        let text = AutoSizedSingleLineText(
            text: "8888",
            fontStyle: .monospacedDigitSystem,
            weight: .heavy,
            maxFontSize: 80,
            minFontSize: 12
        )

        let generousFont = text.fittedFont(allowedWidth: 500, allowedHeight: 500)
        let widthLimitedFont = text.fittedFont(allowedWidth: 72, allowedHeight: 500)
        let heightLimitedFont = text.fittedFont(allowedWidth: 500, allowedHeight: 18)

        #expect(abs(generousFont.pointSize - 80) < 0.001)
        #expect(widthLimitedFont.pointSize < generousFont.pointSize)
        #expect(heightLimitedFont.pointSize < generousFont.pointSize)
        #expect(widthLimitedFont.pointSize >= 12)
        #expect(heightLimitedFont.pointSize >= 12)
    }

    @Test func autoSizedSingleLineTextUsesSampleTextForReservedWidth() {
        let maxFont = NSFont.monospacedDigitSystemFont(ofSize: 80, weight: .heavy)
        let threeDigitWidth = ("000" as NSString).size(withAttributes: [.font: maxFont]).width
        let text = AutoSizedSingleLineText(
            text: "7",
            sampleText: "0000",
            fontStyle: .monospacedDigitSystem,
            weight: .heavy,
            maxFontSize: 80,
            minFontSize: 12
        )

        let fittedFont = text.fittedFont(allowedWidth: threeDigitWidth, allowedHeight: 500)

        #expect(fittedFont.pointSize < 80)
    }

    @Test func autoSizedSingleLineTextBuildsVerticallyCenteredLineRect() {
        let font = NSFont.systemFont(ofSize: 42, weight: .heavy)
        let outerRect = NSRect(x: 12, y: 30, width: 180, height: 92)
        let lineRect = AutoSizedSingleLineText.verticallyCenteredLineRect(font: font, in: outerRect)

        #expect(lineRect.minX == outerRect.minX)
        #expect(lineRect.width == outerRect.width)
        #expect(lineRect.height > 0)
        #expect(lineRect.height <= outerRect.height)
        #expect(abs(lineRect.midY - outerRect.midY) < 0.001)
    }

    @Test func shortcutSingleLineTextRendersNearButtonVerticalCenter() throws {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)
        state.assign(.openFile, to: 2)
        state.setFileConfiguration(Self.fileConfiguration(path: "/Users/ibobby/Documents/report.pdf"), for: 2)
        state.setFileName("报告", for: 2)
        let display = state.display(for: layout.keys[1])

        let png = try H200ButtonIconRenderer().pngData(for: display)
        let image = try #require(NSBitmapImageRep(data: png))
        let textBounds = try #require(Self.brightPixelBounds(in: image))
        let buttonMidY = CGFloat(image.pixelsHigh) / 2

        #expect(abs(textBounds.midY - buttonMidY) < 10)
    }

    @Test func iconRendererUsesBlackButtonBackground() throws {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)
        state.clearFunction(keyID: 4)
        let display = state.display(for: layout.keys[3])

        try Self.expectBlackButtonBackground(for: display)
    }

    @Test func iconRendererUsesBlackBackgroundForPlainFunctions() throws {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)
        state.assign(.sub2API, to: 3)
        state.setSub2APITargetGroupID(1215, for: 3)
        state.setSub2APILastResult(.success(item: Sub2APICapacityItem(
            groupID: 1215,
            groupName: "PLU",
            groupPlatform: "claude",
            concurrencyUsed: 10,
            concurrencyMax: 3188,
            sessionsUsed: 0,
            sessionsMax: 0,
            rpmUsed: 0,
            rpmMax: 0
        )), for: 3)
        state.setTallyDefaultValue(7, for: 4)

        for key in [layout.keys[0], layout.keys[2], layout.keys[3]] {
            try Self.expectBlackButtonBackground(for: state.display(for: key))
        }
    }

    @Test func iconRendererUsesFolderBackgroundAndCenteredName() throws {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)
        state.assign(.openFolder, to: 2)
        state.setFolderConfiguration(Self.folderConfiguration(path: "/Users/ibobby/Documents"), for: 2)
        state.setFolderName("下载", for: 2)
        let display = state.display(for: layout.keys[1])

        let png = try H200ButtonIconRenderer().pngData(for: display)
        let image = try #require(NSBitmapImageRep(data: png))
        let color = try #require(image.colorAt(x: 50, y: 50)?.usingColorSpace(.deviceRGB))

        #expect(display.title == "下载")
        #expect(display.subtitle == "/Users/ibobby/Documents")
        #expect(display.folderButtonContent?.displayName == "下载")
        #expect(color.redComponent + color.greenComponent + color.blueComponent > 0.12)
        #expect(color.alphaComponent > 0.999)
    }

    @Test func iconRendererUsesCustomFolderBackgroundWhenPresent() throws {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)
        let backgroundPNGData = Self.solidColorIconPNGData(color: .systemRed)
        state.assign(.openFolder, to: 2)
        state.setFolderConfiguration(Self.folderConfiguration(
            path: "/Users/ibobby/Documents",
            backgroundPNGData: backgroundPNGData
        ), for: 2)
        state.setFolderName("下载", for: 2)
        state.setButtonVisualDimmingEnabled(false, for: 2)
        let display = state.display(for: layout.keys[1])

        let png = try H200ButtonIconRenderer().pngData(for: display)
        let image = try #require(NSBitmapImageRep(data: png))
        let color = try #require(image.colorAt(x: 2, y: 2)?.usingColorSpace(.deviceRGB))

        #expect(display.folderButtonContent?.backgroundPNGData == backgroundPNGData)
        #expect(color.redComponent > 0.9)
        #expect(color.redComponent > color.greenComponent * 2)
        #expect(color.redComponent > color.blueComponent * 2)
        #expect(color.alphaComponent > 0.999)
    }

    @Test func iconRendererUsesPageFolderBackgroundAndDisplayName() throws {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)
        state.assign(.pageFolder, to: 2)
        state.setButtonVisualDimmingEnabled(false, for: 2)
        let display = state.display(for: layout.keys[1])

        let png = try H200ButtonIconRenderer().pngData(for: display)
        let image = try #require(NSBitmapImageRep(data: png))
        let cornerColor = try #require(image.colorAt(x: 1, y: 1)?.usingColorSpace(.deviceRGB))

        #expect(display.title == "文件夹")
        #expect(display.pageFolderButtonContent?.displayName == "文件夹")
        #expect(cornerColor.redComponent + cornerColor.greenComponent + cornerColor.blueComponent < 0.01)
    }

    @Test func iconRendererUsesBackTextForPageBackKey() throws {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)
        state.assign(.pageFolder, to: 2)
        state.enterPageFolder(keyID: 2)
        let display = state.display(for: layout.keys[0])

        let png = try H200ButtonIconRenderer().pngData(for: display)
        let image = try #require(NSBitmapImageRep(data: png))
        let textBounds = try #require(Self.brightPixelBounds(in: image))

        #expect(display.pageBackButtonContent?.displayName == "返回")
        #expect(textBounds.width > 20)
        #expect(textBounds.height > 10)
    }

    @Test func iconRendererUsesFileNameContentOnBlackBackground() throws {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)
        let iconPNGData = Self.solidColorIconPNGData(color: .systemRed)
        let blurredIconPNGData = Self.solidColorIconPNGData(color: .systemBlue)
        state.assign(.openFile, to: 2)
        state.setFileConfiguration(Self.fileConfiguration(
            path: "/Users/ibobby/Documents/report.pdf",
            iconPNGData: iconPNGData,
            blurredIconPNGData: blurredIconPNGData
        ), for: 2)
        state.setFileName("报告", for: 2)
        state.setButtonVisualDimmingEnabled(false, for: 2)
        let display = state.display(for: layout.keys[1])

        #expect(display.title == "报告")
        #expect(display.subtitle == "/Users/ibobby/Documents/report.pdf")
        #expect(display.fileButtonContent?.displayName == "报告")
        #expect(display.fileButtonContent?.backgroundPNGData == iconPNGData)

        let png = try H200ButtonIconRenderer().pngData(for: display)
        let image = try #require(NSBitmapImageRep(data: png))
        let brightCornerColor = try #require(image.colorAt(x: 1, y: 1)?.usingColorSpace(.deviceRGB))
        #expect(brightCornerColor.redComponent > 0.7)
        #expect(brightCornerColor.redComponent > brightCornerColor.greenComponent + 0.25)
        #expect(brightCornerColor.redComponent > brightCornerColor.blueComponent + 0.25)
        #expect(brightCornerColor.alphaComponent > 0.999)

        state.setButtonVisualDimmingEnabled(true, for: 2)
        let dimmedDisplay = state.display(for: layout.keys[1])
        let dimmedPNG = try H200ButtonIconRenderer().pngData(for: dimmedDisplay)
        let dimmedImage = try #require(NSBitmapImageRep(data: dimmedPNG))
        let dimmedCornerColor = try #require(dimmedImage.colorAt(x: 1, y: 1)?.usingColorSpace(.deviceRGB))
        let brightLuma = brightCornerColor.redComponent + brightCornerColor.greenComponent + brightCornerColor.blueComponent
        let dimmedLuma = dimmedCornerColor.redComponent + dimmedCornerColor.greenComponent + dimmedCornerColor.blueComponent
        #expect(brightLuma > dimmedLuma)

        state.setButtonVisualDimmingEnabled(false, for: 2)
        state.setFileIconBlurEnabled(true, for: 2)
        let blurredDisplay = state.display(for: layout.keys[1])
        let blurredPNG = try H200ButtonIconRenderer().pngData(for: blurredDisplay)
        let blurredImage = try #require(NSBitmapImageRep(data: blurredPNG))
        let blurredCornerColor = try #require(blurredImage.colorAt(x: 1, y: 1)?.usingColorSpace(.deviceRGB))
        #expect(blurredDisplay.fileButtonContent?.backgroundPNGData == blurredIconPNGData)
        #expect(blurredCornerColor.blueComponent > 0.7)
        #expect(blurredCornerColor.blueComponent > blurredCornerColor.redComponent + 0.25)
    }

    @Test func iconRendererCanDisableShortcutBackgroundDimmingPerKey() throws {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)
        state.assign(.openFolder, to: 2)
        state.setFolderConfiguration(Self.folderConfiguration(path: "/Users/ibobby/Documents"), for: 2)
        state.setFolderName("下载", for: 2)
        let dimmedDisplay = state.display(for: layout.keys[1])
        state.setButtonVisualDimmingEnabled(false, for: 2)
        let brightDisplay = state.display(for: layout.keys[1])
        let renderer = H200ButtonIconRenderer()

        let dimmedPNG = try renderer.pngData(for: dimmedDisplay)
        let brightPNG = try renderer.pngData(for: brightDisplay)
        let dimmedImage = try #require(NSBitmapImageRep(data: dimmedPNG))
        let brightImage = try #require(NSBitmapImageRep(data: brightPNG))
        let dimmedColor = try #require(dimmedImage.colorAt(x: 50, y: 50)?.usingColorSpace(.deviceRGB))
        let brightColor = try #require(brightImage.colorAt(x: 50, y: 50)?.usingColorSpace(.deviceRGB))

        let dimmedLuma = dimmedColor.redComponent + dimmedColor.greenComponent + dimmedColor.blueComponent
        let brightLuma = brightColor.redComponent + brightColor.greenComponent + brightColor.blueComponent
        #expect(brightDisplay.renderIdentity != dimmedDisplay.renderIdentity)
        #expect(brightLuma > dimmedLuma)
    }

    @Test func iconRendererUsesSMBBackgroundAndCenteredName() throws {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)
        state.assign(.connectSMBServer, to: 2)
        state.setSMBServerAddress("server/share", for: 2)
        state.setSMBServerName("NAS", for: 2)
        let display = state.display(for: layout.keys[1])

        let png = try H200ButtonIconRenderer().pngData(for: display)
        let image = try #require(NSBitmapImageRep(data: png))
        let color = try #require(image.colorAt(x: 50, y: 50)?.usingColorSpace(.deviceRGB))

        #expect(display.title == "NAS")
        #expect(display.subtitle == "server/share")
        #expect(display.smbServerButtonContent?.displayName == "NAS")
        #expect(color.redComponent + color.greenComponent + color.blueComponent > 0.12)
        #expect(color.alphaComponent > 0.999)
    }

    @Test func iconRendererUsesMihoyoBlurredBackgrounds() throws {
        let layout = DeckGridLayout.h200Prototype
        let cases: [(DeckKeyFunction, MihoyoGame, Int, Int, Int, Int)] = [
            (.genshinStatus, .genshin, 119, 200, 4, 4),
            (.starRailStatus, .starRail, 240, 240, 500, 500),
            (.zenlessZoneStatus, .zenlessZoneZero, 320, 240, 400, 400),
        ]

        for (function, game, currentStamina, maxStamina, dailyCurrent, dailyMax) in cases {
            let status = Self.mihoyoStatus(
                game: game,
                currentStamina: currentStamina,
                maxStamina: maxStamina,
                dailyCurrent: dailyCurrent,
                dailyMax: dailyMax
            )
            var state = DeckGridInteractionState(layout: layout)
            state.assign(function, to: 4)
            state.setMihoyoGameLastResult(.success(status), for: 4)
            let display = state.display(for: layout.keys[3])

            let png = try H200ButtonIconRenderer().pngData(for: display)
            let image = try #require(NSBitmapImageRep(data: png))
            let color = try #require(image.colorAt(x: 12, y: 12)?.usingColorSpace(.deviceRGB))

            #expect(display.mihoyoGame == game)
            #expect(display.mihoyoGameButtonContent?.staminaValue == "\(currentStamina)/\(maxStamina)")
            #expect(display.mihoyoGameButtonContent?.dailyValue == "\(dailyCurrent)/\(dailyMax)")
            #expect(color.redComponent + color.greenComponent + color.blueComponent > 0.12)
            #expect(color.alphaComponent > 0.999)
        }
    }

    @Test func iconRendererDoesNotTintSelectedDisplay() throws {
        let layout = DeckGridLayout.h200Prototype
        var state = DeckGridInteractionState(layout: layout)
        let selectedDisplay = state.display(for: layout.keys[0])
        state.select(keyID: 2)
        let unselectedDisplay = state.display(for: layout.keys[0])
        let renderer = H200ButtonIconRenderer()

        #expect(selectedDisplay.isSelected)
        #expect(!unselectedDisplay.isSelected)
        #expect(try renderer.pngData(for: selectedDisplay) == renderer.pngData(for: unselectedDisplay))
    }

    @Test func chunkedPacketsUseTheObservedH200FrameFormat() {
        let payload = Data(repeating: 0xab, count: H200PacketBuilder.firstChunkDataSize + 2)

        let packets = H200PacketBuilder.buildChunkedPackets(command: H200Command.outSetButtons, payload: payload)

        #expect(packets.count == 2)
        #expect(packets.allSatisfy { $0.count == H200PacketBuilder.packetSize })
        #expect(Array(packets[0].prefix(4)) == [0x7c, 0x7c, 0x00, 0x01])
        #expect(packets[0][4] == UInt8(payload.count & 0xff))
        #expect(packets[0][5] == UInt8((payload.count >> 8) & 0xff))
        #expect(packets[1][0] == 0xab)
        #expect(packets[1][1] == 0xab)
        #expect(packets[1][2] == 0x00)
    }

    @Test func startupPacketsSetButtonsThenSmallWindowBackgroundMode() {
        let package = H200ButtonPackage(
            payload: Data(repeating: 0xab, count: H200PacketBuilder.firstChunkDataSize + 2),
            manifestData: Data(),
            displayCount: 14
        )

        let packets = H200StartupPacketBuilder.buildStartupPackets(package: package)
        let smallWindowPacket = packets.last!
        let smallWindowLength = Self.payloadLength(in: smallWindowPacket)
        let smallWindowPayload = smallWindowPacket.subdata(in: H200PacketBuilder.headerSize..<(H200PacketBuilder.headerSize + smallWindowLength))

        #expect(packets.count == 3)
        #expect(Array(packets[0].prefix(4)) == [0x7c, 0x7c, 0x00, 0x01])
        #expect(Array(smallWindowPacket.prefix(4)) == [0x7c, 0x7c, 0x00, 0x06])
        #expect(smallWindowPayload == H200SmallWindowDataPacketBuilder.backgroundModePayload)
        #expect(String(data: smallWindowPayload, encoding: .utf8) == "2|0|0|00:00:00|0|24H|")
    }

    @Test func smallWindowDataPacketsUseSelectedModePayload() throws {
        let calendar = Calendar(identifier: .gregorian)
        let date = try #require(calendar.date(from: DateComponents(
            timeZone: .current,
            year: 2026,
            month: 6,
            day: 18,
            hour: 12,
            minute: 34,
            second: 56
        )))

        let clockPayload = H200SmallWindowDataPacketBuilder.payload(mode: .dial, date: date)
        let statsPayload = H200SmallWindowDataPacketBuilder.payload(
            mode: .stats,
            date: date,
            systemStats: H200SystemStats(cpuPercent: 37, memoryPercent: 62, gpuPercent: 18)
        )

        #expect(String(data: clockPayload, encoding: .utf8) == "1|0|0|12:34:56|0|24H|")
        #expect(String(data: statsPayload, encoding: .utf8) == "0|37|62|12:34:56|18|24H|")
    }

    @Test func systemStatsPayloadClampsPercentValues() throws {
        let calendar = Calendar(identifier: .gregorian)
        let date = try #require(calendar.date(from: DateComponents(
            timeZone: .current,
            year: 2026,
            month: 6,
            day: 18,
            hour: 12,
            minute: 34,
            second: 56
        )))

        let payload = H200SmallWindowDataPacketBuilder.payload(
            mode: .stats,
            date: date,
            systemStats: H200SystemStats(cpuPercent: -1, memoryPercent: 101, gpuPercent: 42)
        )

        #expect(String(data: payload, encoding: .utf8) == "0|0|100|12:34:56|42|24H|")
    }

    @Test func partialUpdatePacketsUsePartialUpdateCommand() {
        let package = H200ButtonPackage(
            payload: Data(repeating: 0xab, count: H200PacketBuilder.firstChunkDataSize + 2),
            manifestData: Data(),
            displayCount: 1
        )

        let packets = H200PartialUpdatePacketBuilder.buildPartialUpdatePackets(package: package)

        #expect(packets.count == 2)
        #expect(Array(packets[0].prefix(4)) == [0x7c, 0x7c, 0x00, 0x0d])
    }

    @Test func partialUpdateCanAppendSmallWindowModePacket() {
        let package = H200ButtonPackage(
            payload: Data(repeating: 0xab, count: H200PacketBuilder.firstChunkDataSize + 2),
            manifestData: Data(),
            displayCount: 1
        )

        let packets = H200PartialUpdatePacketBuilder.buildPartialUpdatePackets(
            package: package,
            smallWindowMode: .stats,
            systemStats: H200SystemStats(cpuPercent: 37, memoryPercent: 62, gpuPercent: 18)
        )
        let smallWindowPacket = packets.last!
        let smallWindowLength = Self.payloadLength(in: smallWindowPacket)
        let smallWindowPayload = smallWindowPacket.subdata(in: H200PacketBuilder.headerSize..<(H200PacketBuilder.headerSize + smallWindowLength))
        let smallWindowPayloadText = String(data: smallWindowPayload, encoding: .utf8)

        #expect(packets.count == 3)
        #expect(Array(packets[0].prefix(4)) == [0x7c, 0x7c, 0x00, 0x0d])
        #expect(Array(smallWindowPacket.prefix(4)) == [0x7c, 0x7c, 0x00, 0x06])
        #expect(smallWindowPayloadText?.hasPrefix("0|37|62|") == true)
        #expect(smallWindowPayloadText?.hasSuffix("|18|24H|") == true)
    }

    @MainActor
    @Test func partialButtonPackageManifestContainsOnlyRequestedDisplay() throws {
        let layout = DeckGridLayout.h200Prototype
        let state = DeckGridInteractionState(layout: layout)
        let display = state.display(for: layout.keys[6])
        let builder = H200ButtonPackageBuilder(renderer: FakeH200ButtonIconRenderer())

        let package = try builder.buildPackage(displays: [display])
        let manifest = try JSONSerialization.jsonObject(with: package.manifestData) as? [String: Any] ?? [:]
        let entry = manifest["1_1"] as? [String: Any]
        let viewParam = (entry?["ViewParam"] as? [[String: Any]])?.first

        #expect(package.displayCount == 1)
        #expect(manifest.count == 1)
        #expect(viewParam?["Icon"] as? String == "Images/key_7.png")
    }

    @Test func brightnessPacketUsesObservedSimpleFrame() {
        let packet = H200BrightnessPacketBuilder.packet(percent: 140)
        let payloadLength = Self.payloadLength(in: packet)
        let payload = packet.subdata(in: H200PacketBuilder.headerSize..<(H200PacketBuilder.headerSize + payloadLength))

        #expect(packet.count == H200PacketBuilder.packetSize)
        #expect(Array(packet.prefix(4)) == [0x7c, 0x7c, 0x00, 0x0a])
        #expect(String(data: payload, encoding: .utf8) == "100")
    }

    @Test func inputReportParserRecognizesButtonPressReports() {
        let report = Self.inputReport(state: 0x01, index: 13, type: 0x01, action: 0x01)

        let event = H200InputReportParser.parse(report)

        #expect(event == H200InputEvent(state: 0x01, index: 13, type: .button, action: .press))
        #expect(H200DeckInputMapper.keyID(for: event!, layout: .h200Prototype) == 14)
    }

    @Test func inputReportParserIgnoresUnknownReportsAndMapsRelease() {
        var wrongCommand = Self.inputReport(state: 0x01, index: 0, type: 0x01, action: 0x01)
        wrongCommand[3] = 0x02
        let release = Self.inputReport(state: 0x00, index: 0, type: 0x01, action: 0x00)

        let releaseEvent = H200InputReportParser.parse(release)

        #expect(H200InputReportParser.parse(wrongCommand) == nil)
        #expect(releaseEvent == H200InputEvent(state: 0x00, index: 0, type: .button, action: .release))
        #expect(H200DeckInputMapper.keyID(for: releaseEvent!, layout: .h200Prototype) == 1)
    }

    @MainActor
    @Test func smbConnectorFallsBackToWorkspaceWhenNetFSReturnsPermissionError() {
        let mounter = FakeNetFSMounter(status: Int(EPERM))
        let opener = FakeSMBURLOpener()
        let connector = SMBServerConnector(netFSMounter: mounter, urlOpener: opener)

        let didConnect = connector.connect(to: "smb://ibobby-nas.local")

        #expect(didConnect)
        #expect(mounter.mountedURLs.map { $0.absoluteString } == ["smb://ibobby-nas.local"])
        #expect(opener.openedURLs.map { $0.absoluteString } == ["smb://ibobby-nas.local"])
    }

    @MainActor
    @Test func smbConnectorFallsBackToWorkspaceWhenAsyncNetFSCompletionReturnsPermissionError() {
        let mounter = FakeNetFSMounter(status: 0, completionStatus: Int(EPERM))
        let opener = FakeSMBURLOpener()
        let connector = SMBServerConnector(netFSMounter: mounter, urlOpener: opener)

        let didConnect = connector.connect(to: "smb://ibobby-nas.local")
        mounter.completePendingMount()

        #expect(didConnect)
        #expect(mounter.mountedURLs.map { $0.absoluteString } == ["smb://ibobby-nas.local"])
        #expect(opener.openedURLs.map { $0.absoluteString } == ["smb://ibobby-nas.local"])
    }

    @MainActor
    @Test func smbConnectorDoesNotFallbackForOtherNetFSErrors() {
        let mounter = FakeNetFSMounter(status: Int(ENOENT))
        let opener = FakeSMBURLOpener()
        let connector = SMBServerConnector(netFSMounter: mounter, urlOpener: opener)

        let didConnect = connector.connect(to: "ibobby-nas.local")

        #expect(!didConnect)
        #expect(mounter.mountedURLs.map { $0.absoluteString } == ["smb://ibobby-nas.local"])
        #expect(opener.openedURLs.isEmpty)
    }

    @Test func zzzStatusUsesVitalityAndDoesNotClampOverCapEnergy() {
        let role = Self.mihoyoRole(game: .zenlessZoneZero)
        let status = MihoyoGameStatusMapper.dailyStatus(
            for: role,
            data: [
                "energy": [
                    "progress": [
                        "current": 320,
                        "max": 240,
                    ],
                    "restore": 0,
                ],
                "vitality": [
                    "current": 400,
                    "max": 400,
                ],
                "bounty_commission": [
                    "num": 2,
                    "total": 4,
                ],
            ],
            source: .record
        )

        #expect(status.staminaName == "电量")
        #expect(status.currentStamina == 320)
        #expect(status.maxStamina == 240)
        #expect(status.staminaValueText == "320/240")
        #expect(status.dailyName == "活跃度")
        #expect(status.dailyCurrent == 400)
        #expect(status.dailyMax == 400)
        #expect(status.dailyDone == true)
        #expect(status.buttonTitle == "电量 320/240")
        #expect(status.buttonSubtitle == "每日活跃度 400/400")
        #expect(status.buttonContent == MihoyoGameButtonContent(
            game: .zenlessZoneZero,
            staminaLabel: "电量",
            staminaValue: "320/240",
            dailyLabel: "每日活跃度",
            dailyValue: "400/400"
        ))
    }

    @Test func mihoyoJSONParsesNumericRetcodeWithoutTreatingItAsBool() throws {
        let rawData = try #require(
            """
            {"retcode":0,"data":{"code":200},"success":false}
            """.data(using: .utf8)
        )
        let payload = try #require(try JSONSerialization.jsonObject(with: rawData) as? [String: Any])
        let data = try #require(payload["data"] as? [String: Any])

        #expect(MihoyoJSON.int(payload["retcode"]) == 0)
        #expect(MihoyoJSON.int(data["code"]) == 200)
        #expect(MihoyoJSON.int(NSNumber(value: 0)) == 0)
        #expect(MihoyoJSON.int(payload["success"]) == nil)
        #expect(MihoyoJSON.int(NSNumber(value: false)) == nil)
    }

    @Test func gameFunctionDisplaysLatestStatusAndErrorStates() {
        let layout = DeckGridLayout.h200Prototype
        let status = Self.mihoyoStatus(
            game: .zenlessZoneZero,
            currentStamina: 320,
            maxStamina: 240,
            dailyCurrent: 400,
            dailyMax: 400
        )
        var state = DeckGridInteractionState(layout: layout)

        state.assign(.zenlessZoneStatus, to: 5)
        var display = state.display(for: layout.keys[4])

        #expect(display.title == "绝区零")
        #expect(display.subtitle == "未查询")
        #expect(display.mihoyoGame == .zenlessZoneZero)
        #expect(display.mihoyoGameButtonContent == nil)

        state.setMihoyoGameLastResult(.success(status), for: 5)
        display = state.display(for: layout.keys[4])

        #expect(display.title == "电量 320/240")
        #expect(display.subtitle == "每日活跃度 400/400")
        #expect(display.mihoyoGame == .zenlessZoneZero)
        #expect(display.mihoyoGameButtonContent == MihoyoGameButtonContent(
            game: .zenlessZoneZero,
            staminaLabel: "电量",
            staminaValue: "320/240",
            dailyLabel: "每日活跃度",
            dailyValue: "400/400"
        ))

        state.setMihoyoGameLastResult(.loginExpired("登录已失效"), for: 5)
        display = state.display(for: layout.keys[4])

        #expect(display.title == "绝区零")
        #expect(display.subtitle == "需重登")
    }

    @Test func gameRuntimeStatusIsNotPersistedWithDeckConfiguration() throws {
        let suiteName = "UlanziDeckSwiftTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let layout = DeckGridLayout.h200Prototype
        let store = UserDefaultsDeckConfigurationStore(defaults: defaults, storageKey: "deckConfiguration")
        var state = DeckGridInteractionState(layout: layout)
        state.assign(.genshinStatus, to: 3)
        state.setMihoyoGameRefreshIntervalMinutes(45, for: 3)
        state.setMihoyoGameLastResult(.success(Self.mihoyoStatus(game: .genshin)), for: 3)

        store.saveInteractionState(state, for: layout)

        let restored = try #require(store.loadInteractionState(for: layout))
        #expect(restored.configuration(for: 3)?.function == .genshinStatus)
        #expect(restored.configuration(for: 3)?.mihoyoGame.refreshIntervalMinutes == 45)
        #expect(restored.configuration(for: 3)?.mihoyoGame.lastResult == nil)
    }

    @MainActor
    @Test func assigningGameFunctionUsesSharedStoredLoginSession() async throws {
        let session = Self.mihoyoSession()
        let status = Self.mihoyoStatus(game: .genshin, currentStamina: 180, maxStamina: 200)
        let mihoyoService = FakeMihoyoGameService(fetchResults: [.success(status)])
        let sessionStore = FakeMihoyoSessionStore(loadedSession: session)
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore(),
            mihoyoGameService: mihoyoService,
            mihoyoSessionStore: sessionStore
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        model.selectKey(keyID: 4)
        model.assignSelectedFunction(.genshinStatus)

        try await Self.waitUntil {
            syncer.partialDisplays.last?.first?.title == "树脂 180/200"
        }

        #expect(model.mihoyoLoginState == .loggedIn(accountID: session.accountID))
        #expect(mihoyoService.fetchRequests.map(\.game) == [.genshin])
        #expect(model.interactionState.configuration(for: 4)?.mihoyoGame.lastResult == .success(status))
        #expect(syncer.partialDisplays.last?.first?.subtitle == "每日委托 4/4")
    }

    @MainActor
    @Test func gameRefreshIntervalAutomaticallyRefetchesStatus() async throws {
        let session = Self.mihoyoSession()
        let firstStatus = Self.mihoyoStatus(game: .starRail, currentStamina: 94, maxStamina: 300, dailyCurrent: 200, dailyMax: 500)
        let secondStatus = Self.mihoyoStatus(game: .starRail, currentStamina: 120, maxStamina: 300, dailyCurrent: 500, dailyMax: 500)
        let mihoyoService = FakeMihoyoGameService(
            fetchResults: [.success(firstStatus), .success(secondStatus)],
            defaultFetchResult: .success(secondStatus)
        )
        let layout = DeckGridLayout.h200Prototype
        var loadedState = DeckGridInteractionState(layout: layout)
        loadedState.assign(.starRailStatus, to: 6)
        loadedState.setMihoyoGameRefreshIntervalMinutes(1, for: 6)
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: FakeH200DeckSyncer(),
            configurationStore: FakeDeckConfigurationStore(loadedState: loadedState),
            mihoyoGameService: mihoyoService,
            mihoyoSessionStore: FakeMihoyoSessionStore(loadedSession: session),
            mihoyoGameRefreshMinuteDuration: 0.01
        )

        model.checkOnLaunch()

        try await Self.waitUntil {
            mihoyoService.fetchRequests.count >= 2
                && model.interactionState.configuration(for: 6)?.mihoyoGame.lastResult == .success(secondStatus)
        }

        #expect(Array(mihoyoService.fetchRequests.prefix(2).map(\.game)) == [.starRail, .starRail])
        #expect(model.interactionState.configuration(for: 6)?.mihoyoGame.lastResult == .success(secondStatus))
        model.clearKeyFunction(keyID: 6)
        #expect(model.interactionState.configuration(for: 6)?.mihoyoGame.lastResult == nil)
    }

    @MainActor
    @Test func mihoyoGameTimerKeepsRemainingDelayAfterSwap() async throws {
        let session = Self.mihoyoSession()
        let firstStatus = Self.mihoyoStatus(game: .starRail, currentStamina: 94, maxStamina: 300, dailyCurrent: 200, dailyMax: 500)
        let secondStatus = Self.mihoyoStatus(game: .starRail, currentStamina: 120, maxStamina: 300, dailyCurrent: 500, dailyMax: 500)
        let mihoyoService = FakeMihoyoGameService(
            fetchResults: [.success(firstStatus), .success(secondStatus)],
            defaultFetchResult: .success(secondStatus)
        )
        let layout = DeckGridLayout.h200Prototype
        var loadedState = DeckGridInteractionState(layout: layout)
        loadedState.assign(.starRailStatus, to: 6)
        loadedState.setMihoyoGameRefreshIntervalMinutes(1, for: 6)
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: FakeH200DeckSyncer(),
            configurationStore: FakeDeckConfigurationStore(loadedState: loadedState),
            mihoyoGameService: mihoyoService,
            mihoyoSessionStore: FakeMihoyoSessionStore(loadedSession: session),
            mihoyoGameRefreshMinuteDuration: 0.1
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            mihoyoService.fetchRequests.count == 1
                && model.interactionState.configuration(for: 6)?.mihoyoGame.lastResult == .success(firstStatus)
        }
        try await Task.sleep(nanoseconds: 40_000_000)

        model.swapSquareKeyConfigurations(sourceKeyID: 6, targetKeyID: 5)
        try await Task.sleep(nanoseconds: 80_000_000)

        #expect(mihoyoService.fetchRequests.count >= 2)
        #expect(model.interactionState.configuration(for: 6)?.function != .starRailStatus)
        #expect(model.interactionState.configuration(for: 5)?.mihoyoGame.lastResult == .success(secondStatus))
    }

    @MainActor
    @Test func mihoyoGameRefreshIntervalSameClampedValueDoesNotPersist() {
        let layout = DeckGridLayout.h200Prototype
        var loadedState = DeckGridInteractionState(layout: layout)
        loadedState.assign(.genshinStatus, to: 4)
        loadedState.setMihoyoGameRefreshIntervalMinutes(1, for: 4)
        let store = FakeDeckConfigurationStore(loadedState: loadedState)
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.notConnected]),
            syncer: FakeH200DeckSyncer(),
            configurationStore: store
        )

        model.selectKey(keyID: 4)
        model.setSelectedMihoyoGameRefreshIntervalMinutes(0)

        #expect(store.savedStates.isEmpty)
        #expect(model.interactionState.configuration(for: 4)?.mihoyoGame.refreshIntervalMinutes == 1)
    }

    @MainActor
    @Test func expiredGameQueryClearsSharedLoginAndMarksAllGameKeysExpired() async throws {
        let session = Self.mihoyoSession()
        let sessionStore = FakeMihoyoSessionStore(loadedSession: session)
        let mihoyoService = FakeMihoyoGameService(defaultFetchResult: .loginExpired("Cookie 已失效"))
        let layout = DeckGridLayout.h200Prototype
        var loadedState = DeckGridInteractionState(layout: layout)
        loadedState.assign(.genshinStatus, to: 1)
        loadedState.assign(.zenlessZoneStatus, to: 2)
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: FakeH200DeckSyncer(),
            configurationStore: FakeDeckConfigurationStore(loadedState: loadedState),
            mihoyoGameService: mihoyoService,
            mihoyoSessionStore: sessionStore
        )

        model.checkOnLaunch()

        try await Self.waitUntil {
            model.mihoyoLoginState == .expired("Cookie 已失效")
        }

        #expect(sessionStore.clearCount >= 1)
        #expect(model.interactionState.configuration(for: 1)?.mihoyoGame.lastResult == .loginExpired("Cookie 已失效"))
        #expect(model.interactionState.configuration(for: 2)?.mihoyoGame.lastResult == .loginExpired("Cookie 已失效"))
    }

    @MainActor
    @Test func gameLoginRequiredStopsRefreshesUntilQRCodeLoginSucceeds() async throws {
        let oldSession = Self.mihoyoSession(accountID: "100001")
        let newSession = Self.mihoyoSession(accountID: "100002")
        let qrSession = MihoyoQRLoginSession(ticket: "ticket", url: "https://example.com/login", deviceID: "device")
        let status = Self.mihoyoStatus(game: .genshin, currentStamina: 180, maxStamina: 200)
        let sessionStore = FakeMihoyoSessionStore(loadedSession: oldSession)
        let mihoyoService = FakeMihoyoGameService(
            createdQRCode: qrSession,
            qrResults: [.confirmed(newSession)],
            fetchResultsByAccountID: [
                oldSession.accountID: .loginRequired,
                newSession.accountID: .success(status),
            ]
        )
        let layout = DeckGridLayout.h200Prototype
        var loadedState = DeckGridInteractionState(layout: layout)
        loadedState.assign(.genshinStatus, to: 4)
        loadedState.setMihoyoGameRefreshIntervalMinutes(1, for: 4)
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: FakeH200DeckSyncer(),
            configurationStore: FakeDeckConfigurationStore(loadedState: loadedState),
            mihoyoGameService: mihoyoService,
            mihoyoSessionStore: sessionStore,
            mihoyoLoginPollNanoseconds: 1_000_000,
            mihoyoGameRefreshMinuteDuration: 0.01
        )

        model.checkOnLaunch()

        try await Self.waitUntil {
            model.mihoyoLoginState == .notLoggedIn
                && model.interactionState.configuration(for: 4)?.mihoyoGame.lastResult == .loginRequired
        }
        let pausedRequestCount = mihoyoService.fetchRequests.count
        try await Task.sleep(nanoseconds: 80_000_000)
        #expect(mihoyoService.fetchRequests.count == pausedRequestCount)

        model.beginMihoyoQRCodeLogin()

        try await Self.waitUntil {
            model.mihoyoLoginState == .loggedIn(accountID: newSession.accountID)
                && model.interactionState.configuration(for: 4)?.mihoyoGame.lastResult == .success(status)
        }

        #expect(sessionStore.clearCount >= 2)
        #expect(sessionStore.savedSessions == [newSession])
        #expect(mihoyoService.fetchRequests.contains {
            $0.session == oldSession && $0.game == .genshin
        })
        #expect(mihoyoService.fetchRequests.contains {
            $0.session == newSession && $0.game == .genshin
        })
    }

    @MainActor
    @Test func gameNetworkErrorKeepsRefreshTimerAndLoginSession() async throws {
        let session = Self.mihoyoSession()
        let sessionStore = FakeMihoyoSessionStore(loadedSession: session)
        let mihoyoService = FakeMihoyoGameService(defaultFetchResult: .networkError("网络未连接"))
        let layout = DeckGridLayout.h200Prototype
        var loadedState = DeckGridInteractionState(layout: layout)
        loadedState.assign(.starRailStatus, to: 6)
        loadedState.setMihoyoGameRefreshIntervalMinutes(1, for: 6)
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: FakeH200DeckSyncer(),
            configurationStore: FakeDeckConfigurationStore(loadedState: loadedState),
            mihoyoGameService: mihoyoService,
            mihoyoSessionStore: sessionStore,
            mihoyoGameRefreshMinuteDuration: 0.01
        )

        model.checkOnLaunch()

        try await Self.waitUntil {
            mihoyoService.fetchRequests.count >= 2
                && model.interactionState.configuration(for: 6)?.mihoyoGame.lastResult == .networkError("网络未连接")
        }

        #expect(model.mihoyoLoginState == .loggedIn(accountID: session.accountID))
        #expect(sessionStore.clearCount == 0)
        #expect(mihoyoService.fetchRequests.prefix(2).allSatisfy {
            $0.session == session && $0.game == .starRail
        })
    }

    @MainActor
    @Test func qrLoginStoresSharedSessionAndRefreshesConfiguredGameKeys() async throws {
        let session = Self.mihoyoSession(accountID: "100002")
        let qrSession = MihoyoQRLoginSession(ticket: "ticket", url: "https://example.com/login", deviceID: "device")
        let status = Self.mihoyoStatus(game: .starRail, currentStamina: 94, maxStamina: 300, dailyCurrent: 500, dailyMax: 500)
        let mihoyoService = FakeMihoyoGameService(
            createdQRCode: qrSession,
            qrResults: [.scanned, .confirmed(session)],
            fetchResults: [.success(status)]
        )
        let sessionStore = FakeMihoyoSessionStore()
        let layout = DeckGridLayout.h200Prototype
        var loadedState = DeckGridInteractionState(layout: layout)
        loadedState.assign(.starRailStatus, to: 6)
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore(loadedState: loadedState),
            mihoyoGameService: mihoyoService,
            mihoyoSessionStore: sessionStore,
            mihoyoLoginPollNanoseconds: 1_000_000
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        model.beginMihoyoQRCodeLogin()

        try await Self.waitUntil {
            model.mihoyoLoginState == .loggedIn(accountID: session.accountID)
                && model.interactionState.configuration(for: 6)?.mihoyoGame.lastResult == .success(status)
        }

        #expect(sessionStore.savedSessions == [session])
        #expect(sessionStore.clearCount == 1)
        #expect(mihoyoService.queryRequests == [qrSession, qrSession])
        #expect(mihoyoService.fetchRequests.map(\.game) == [.starRail])
    }

    @MainActor
    @Test func qrLoginIgnoresStaleGameFetchFromPreviousSession() async throws {
        let oldSession = Self.mihoyoSession(accountID: "100001")
        let newSession = Self.mihoyoSession(accountID: "100002")
        let qrSession = MihoyoQRLoginSession(ticket: "ticket", url: "https://example.com/login", deviceID: "device")
        let status = Self.mihoyoStatus(game: .starRail, currentStamina: 120, maxStamina: 300, dailyCurrent: 500, dailyMax: 500)
        let mihoyoService = FakeMihoyoGameService(
            createdQRCode: qrSession,
            qrResults: [.confirmed(newSession)],
            fetchResultsByAccountID: [
                oldSession.accountID: .loginExpired("旧会话已失效"),
                newSession.accountID: .success(status),
            ],
            fetchDelayNanoseconds: 80_000_000
        )
        let sessionStore = FakeMihoyoSessionStore(loadedSession: oldSession)
        let layout = DeckGridLayout.h200Prototype
        var loadedState = DeckGridInteractionState(layout: layout)
        loadedState.assign(.starRailStatus, to: 6)
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore(loadedState: loadedState),
            mihoyoGameService: mihoyoService,
            mihoyoSessionStore: sessionStore,
            mihoyoLoginPollNanoseconds: 1_000_000
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        model.selectKey(keyID: 6)
        model.refreshSelectedMihoyoGameStatus()
        try await Self.waitUntil {
            mihoyoService.fetchRequests.count == 1
        }
        model.beginMihoyoQRCodeLogin()

        try await Self.waitUntil {
            model.mihoyoLoginState == .loggedIn(accountID: newSession.accountID)
                && model.interactionState.configuration(for: 6)?.mihoyoGame.lastResult == .success(status)
        }
        try await Task.sleep(nanoseconds: 120_000_000)

        #expect(model.mihoyoLoginState == .loggedIn(accountID: newSession.accountID))
        #expect(model.interactionState.configuration(for: 6)?.mihoyoGame.lastResult == .success(status))
        #expect(sessionStore.savedSessions == [newSession])
        #expect(mihoyoService.fetchRequests.first?.session == oldSession)
        #expect(mihoyoService.fetchRequests.contains { $0.session == newSession })
    }

    @MainActor
    @Test func staleGameFetchIsIgnoredAfterKeySwitchesGame() async throws {
        let session = Self.mihoyoSession()
        let genshinStatus = Self.mihoyoStatus(game: .genshin, currentStamina: 160, maxStamina: 200)
        let starRailStatus = Self.mihoyoStatus(game: .starRail, currentStamina: 240, maxStamina: 300)
        let mihoyoService = FakeMihoyoGameService(
            fetchResults: [
                .success(genshinStatus),
                .success(starRailStatus),
            ],
            fetchDelayNanoseconds: 80_000_000
        )
        let syncer = FakeH200DeckSyncer()
        let model = H200ConnectionModel(
            discovery: FakeH200Discovery(results: [.connected(Self.protocolInterfaceIdentity())]),
            syncer: syncer,
            configurationStore: FakeDeckConfigurationStore(),
            mihoyoGameService: mihoyoService,
            mihoyoSessionStore: FakeMihoyoSessionStore(loadedSession: session)
        )

        model.checkOnLaunch()
        try await Self.waitUntil {
            syncer.sentDisplays.count == 1 && model.syncSummary != nil
        }
        model.selectKey(keyID: 4)
        model.assignSelectedFunction(.genshinStatus)
        try await Self.waitUntil {
            mihoyoService.fetchRequests.count == 1
        }
        model.assignSelectedFunction(.starRailStatus)

        try await Self.waitUntil {
            model.interactionState.configuration(for: 4)?.mihoyoGame.lastResult == .success(starRailStatus)
        }
        try await Task.sleep(nanoseconds: 120_000_000)

        #expect(model.interactionState.mihoyoGame(for: 4) == .starRail)
        #expect(model.interactionState.configuration(for: 4)?.mihoyoGame.lastResult == .success(starRailStatus))
        #expect(mihoyoService.fetchRequests.map(\.game) == [.genshin, .starRail])
    }

    private static func protocolInterfaceIdentity() -> H200DeviceIdentity {
        H200DeviceIdentity(
            vendorID: H200DeviceTarget.vendorID,
            productID: H200DeviceTarget.productID,
            locationID: 0x01124300,
            primaryUsagePage: H200DeviceTarget.primaryUsagePage,
            primaryUsage: H200DeviceTarget.primaryUsage,
            maxInputReportSize: H200DeviceTarget.reportSize,
            maxOutputReportSize: H200DeviceTarget.reportSize,
            serialNumber: "70973ca7355917c7",
            manufacturer: "rockchip",
            product: ""
        )
    }

    private static func exclusiveAccessReturnCode() -> HIDReturnCode {
        HIDReturnCode(rawValue: Int32(bitPattern: 0xe00002c5))
    }

    private static func payloadLength(in packet: Data) -> Int {
        Int(packet[4])
            | (Int(packet[5]) << 8)
            | (Int(packet[6]) << 16)
            | (Int(packet[7]) << 24)
    }

    private static func expectBlackButtonBackground(for display: DeckKeyDisplay) throws {
        let png = try H200ButtonIconRenderer().pngData(for: display)
        let image = try #require(NSBitmapImageRep(data: png))
        let samplePoints = [
            (x: 1, y: 1),
            (x: display.devicePixelSize.width / 12, y: display.devicePixelSize.height / 2),
            (x: display.devicePixelSize.width / 2, y: display.devicePixelSize.height / 12),
        ]

        for point in samplePoints {
            let color = try #require(image.colorAt(x: point.x, y: point.y)?.usingColorSpace(.deviceRGB))

            #expect(color.redComponent < 0.001)
            #expect(color.greenComponent < 0.001)
            #expect(color.blueComponent < 0.001)
            #expect(color.alphaComponent > 0.999)
        }
    }

    private static func bitmapContainsPixel(
        in image: NSBitmapImageRep,
        xRange: Range<Int>,
        yRange: Range<Int>,
        matching predicate: (NSColor) -> Bool
    ) -> Bool {
        for x in xRange where x >= 0 && x < image.pixelsWide {
            for y in yRange where y >= 0 && y < image.pixelsHigh {
                guard let color = image.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
                    continue
                }
                if predicate(color) {
                    return true
                }
            }
        }

        return false
    }

    private static func brightPixelBounds(in image: NSBitmapImageRep) -> NSRect? {
        var minX = Int.max
        var minY = Int.max
        var maxX = Int.min
        var maxY = Int.min

        for x in 0..<image.pixelsWide {
            for y in 0..<image.pixelsHigh {
                guard let color = image.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                      color.alphaComponent > 0.8,
                      color.redComponent > 0.72,
                      color.greenComponent > 0.72,
                      color.blueComponent > 0.72
                else {
                    continue
                }

                minX = Swift.min(minX, x)
                minY = Swift.min(minY, y)
                maxX = Swift.max(maxX, x)
                maxY = Swift.max(maxY, y)
            }
        }

        guard minX <= maxX, minY <= maxY else {
            return nil
        }

        return NSRect(
            x: minX,
            y: minY,
            width: maxX - minX + 1,
            height: maxY - minY + 1
        )
    }

    private static func inputReport(state: UInt8, index: UInt8, type: UInt8, action: UInt8) -> Data {
        var report = Data()
        report.append(0x7c)
        report.append(0x7c)
        report.appendUInt16BE(H200Command.inButton)
        report.appendUInt32LE(4)
        report.append(state)
        report.append(index)
        report.append(type)
        report.append(action)
        report.append(Data(repeating: 0, count: H200DeviceTarget.reportSize - report.count))
        return report
    }

    private static func waitUntil(_ condition: @escaping () -> Bool) async throws {
        for _ in 0..<60 {
            if condition() {
                return
            }

            try await Task.sleep(nanoseconds: 50_000_000)
        }

        #expect(condition())
    }

    private static func hasSyncedDisplayTitle(_ title: String, for keyID: Int, syncer: FakeH200DeckSyncer) -> Bool {
        let sentDisplayMatches = syncer.sentDisplays.contains { displays in
            displays.contains { $0.id == keyID && $0.title == title }
        }
        let partialDisplayMatches = syncer.partialDisplays.contains { displays in
            displays.contains { $0.id == keyID && $0.title == title }
        }

        return sentDisplayMatches || partialDisplayMatches
    }

    private static func folderConfiguration(
        path: String,
        bookmarkData: Data? = Data("bookmark".utf8),
        name: String = "",
        backgroundPNGData: Data? = nil
    ) -> DeckKeyOpenFolderConfiguration {
        DeckKeyOpenFolderConfiguration(
            path: path,
            bookmarkData: bookmarkData,
            name: name,
            backgroundPNGData: backgroundPNGData
        )
    }

    private static func fileConfiguration(
        path: String,
        bookmarkData: Data? = Data("bookmark".utf8),
        name: String = "",
        iconPNGData: Data? = nil,
        blurredIconPNGData: Data? = nil,
        usesBlurredIcon: Bool = false
    ) -> DeckKeyOpenFileConfiguration {
        DeckKeyOpenFileConfiguration(
            path: path,
            bookmarkData: bookmarkData,
            name: name,
            iconPNGData: iconPNGData,
            blurredIconPNGData: blurredIconPNGData,
            usesBlurredIcon: usesBlurredIcon
        )
    }

    private static func solidColorIconPNGData(color: NSColor) -> Data {
        let pixelSize = 64
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelSize,
            pixelsHigh: pixelSize,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            Issue.record("无法创建测试图标位图")
            return Data()
        }

        rep.size = NSSize(width: pixelSize, height: pixelSize)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        color.setFill()
        NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize).fill()
        NSGraphicsContext.restoreGraphicsState()

        guard let pngData = rep.representation(using: .png, properties: [:]) else {
            Issue.record("无法编码测试图标 PNG")
            return Data()
        }
        return pngData
    }

    private static func twoToneIconImage() -> NSImage {
        let size = NSSize(width: 80, height: 40)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemRed.setFill()
        NSRect(x: 0, y: 0, width: 40, height: 40).fill()
        NSColor.systemBlue.setFill()
        NSRect(x: 40, y: 0, width: 40, height: 40).fill()
        image.unlockFocus()
        return image
    }

    private static func sub2APICapacityItem(
        groupID: Int,
        groupName: String,
        availableConcurrency: Int
    ) -> Sub2APICapacityItem {
        Sub2APICapacityItem(
            groupID: groupID,
            groupName: groupName,
            groupPlatform: "claude",
            concurrencyUsed: 0,
            concurrencyMax: availableConcurrency,
            sessionsUsed: 0,
            sessionsMax: 0,
            rpmUsed: 0,
            rpmMax: 0
        )
    }

    private static func mihoyoRole(game: MihoyoGame, uid: String = "100000001") -> MihoyoBoundRole {
        MihoyoBoundRole(
            game: game,
            gameBiz: game.roleGameBiz,
            gameUID: uid,
            region: "cn_gf01",
            nickname: game.shortDisplayName,
            level: 60
        )
    }

    private static func mihoyoStatus(
        game: MihoyoGame,
        currentStamina: Int = 160,
        maxStamina: Int = 200,
        dailyCurrent: Int = 4,
        dailyMax: Int = 4
    ) -> MihoyoDailyStatus {
        let staminaName: String
        let dailyName: String
        switch game {
        case .genshin:
            staminaName = "树脂"
            dailyName = "每日委托"
        case .starRail:
            staminaName = "开拓力"
            dailyName = "每日实训"
        case .zenlessZoneZero:
            staminaName = "电量"
            dailyName = "活跃度"
        }

        return MihoyoDailyStatus(
            game: game,
            role: mihoyoRole(game: game),
            staminaName: staminaName,
            currentStamina: currentStamina,
            maxStamina: maxStamina,
            staminaRecoverSeconds: 0,
            dailyName: dailyName,
            dailyCurrent: dailyCurrent,
            dailyMax: dailyMax,
            dailyDone: dailyCurrent == dailyMax,
            source: .record
        )
    }

    private static func mihoyoSession(accountID: String = "100001") -> MihoyoLoginSession {
        MihoyoLoginSession(
            accountID: accountID,
            stokenV2: "stoken",
            mid: "mid",
            cookieToken: "cookie",
            ltoken: "ltoken",
            deviceID: "device-id",
            deviceFP: "device-fp"
        )
    }
}

private final class FakeH200DeckSyncer: H200DeckSyncing, @unchecked Sendable {
    private let lock = NSLock()
    private var results: [H200DeckSyncResult]
    private var brightnessResults: [H200DeckSyncFailure?]
    private var storedSentDisplays: [[DeckKeyDisplay]] = []
    private var storedPartialDisplays: [[DeckKeyDisplay]] = []
    private var storedBrightnessPercents: [Int] = []
    private var storedSmallWindowModes: [H200SmallWindowMode] = []
    private var storedInternalRefreshPausedValues: [Bool] = []
    private var inputHandler: H200InputHandler?
    private let packageDelayNanoseconds: UInt64
    private let brightnessDelayNanoseconds: UInt64

    var sentDisplays: [[DeckKeyDisplay]] {
        locked { storedSentDisplays }
    }

    var partialDisplays: [[DeckKeyDisplay]] {
        locked { storedPartialDisplays }
    }

    var brightnessPercents: [Int] {
        locked { storedBrightnessPercents }
    }

    var smallWindowModes: [H200SmallWindowMode] {
        locked { storedSmallWindowModes }
    }

    var internalRefreshPausedValues: [Bool] {
        locked { storedInternalRefreshPausedValues }
    }

    init(
        results: [H200DeckSyncResult] = [],
        brightnessFailures: [H200DeckSyncFailure] = [],
        brightnessResults: [H200DeckSyncFailure?]? = nil,
        packageDelayNanoseconds: UInt64 = 0,
        brightnessDelayNanoseconds: UInt64 = 0
    ) {
        self.results = results
        self.brightnessResults = brightnessResults ?? brightnessFailures.map { Optional.some($0) }
        self.packageDelayNanoseconds = packageDelayNanoseconds
        self.brightnessDelayNanoseconds = brightnessDelayNanoseconds
    }

    func sendStartupPackage(displays: [DeckKeyDisplay]) -> H200DeckSyncResult {
        let startedAt = DispatchTime.now().uptimeNanoseconds
        sleepIfNeeded(packageDelayNanoseconds)
        let result = locked {
            storedSentDisplays.append(displays)

            guard !results.isEmpty else {
                return H200DeckSyncResult.success(H200DeckSyncSummary(
                    payloadByteCount: displays.count,
                    packetCount: 1,
                    displayCount: displays.count
                ))
            }

            return results.removeFirst()
        }

        return result.withElapsedNanoseconds(DispatchTime.now().uptimeNanoseconds - startedAt)
    }

    func sendPartialPackage(displays: [DeckKeyDisplay]) -> H200DeckSyncResult {
        let startedAt = DispatchTime.now().uptimeNanoseconds
        sleepIfNeeded(packageDelayNanoseconds)
        let result = locked {
            storedPartialDisplays.append(displays)
            if let smallWindowMode = H200SmallWindowMode.modeIfPresent(in: displays) {
                storedSmallWindowModes.append(smallWindowMode)
            }

            return H200DeckSyncResult.success(H200DeckSyncSummary(
                payloadByteCount: displays.count,
                packetCount: 1,
                displayCount: displays.count
            ))
        }

        return result.withElapsedNanoseconds(DispatchTime.now().uptimeNanoseconds - startedAt)
    }

    func setBrightness(percent: Int) -> H200DeckCommandResult {
        sleepIfNeeded(brightnessDelayNanoseconds)

        let error = locked {
            storedBrightnessPercents.append(percent)
            guard !brightnessResults.isEmpty else {
                return H200DeckSyncFailure?.none
            }

            return brightnessResults.removeFirst()
        }

        if let error {
            return .failure(error, elapsedNanoseconds: brightnessDelayNanoseconds)
        }

        return .success(elapsedNanoseconds: brightnessDelayNanoseconds)
    }

    func setInternalRefreshPaused(_ paused: Bool) {
        locked {
            storedInternalRefreshPausedValues.append(paused)
        }
    }

    func setInputHandler(_ handler: H200InputHandler?) {
        locked {
            inputHandler = handler
        }
    }

    func emitInput(_ event: H200InputEvent) {
        let handler = locked { inputHandler }
        handler?(event)
    }

    private func locked<Value>(_ body: () -> Value) -> Value {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    private func sleepIfNeeded(_ nanoseconds: UInt64) {
        guard nanoseconds > 0 else {
            return
        }

        Thread.sleep(forTimeInterval: Double(nanoseconds) / 1_000_000_000)
    }
}

private extension H200DeckSyncResult {
    func withElapsedNanoseconds(_ elapsedNanoseconds: UInt64) -> H200DeckSyncResult {
        switch self {
        case let .success(summary):
            return .success(H200DeckSyncSummary(
                payloadByteCount: summary.payloadByteCount,
                packetCount: summary.packetCount,
                displayCount: summary.displayCount,
                elapsedNanoseconds: elapsedNanoseconds
            ))
        case let .failure(error, _):
            return .failure(error, elapsedNanoseconds: elapsedNanoseconds)
        }
    }
}

private struct FakeH200ButtonIconRenderer: H200ButtonIconRendering {
    func pngData(for display: DeckKeyDisplay) throws -> Data {
        Data([0x89, 0x50, 0x4e, 0x47, UInt8(display.id)])
    }
}

private struct FailingH200ButtonIconRenderer: H200ButtonIconRendering {
    func pngData(for display: DeckKeyDisplay) throws -> Data {
        throw H200ButtonIconRenderError.cannotEncodePNG
    }
}

private final class FakeH200Discovery: H200Discovering, @unchecked Sendable {
    private let lock = NSLock()
    private var results: [H200DiscoveryResult]

    init(results: [H200DiscoveryResult]) {
        self.results = results
    }

    func discoverH200() -> H200DiscoveryResult {
        locked {
            guard !results.isEmpty else {
                return .notConnected
            }

            return results.removeFirst()
        }
    }

    private func locked<Value>(_ body: () -> Value) -> Value {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

private final class FakeSub2APIFetcher: Sub2APIFetching, @unchecked Sendable {
    struct Request: Equatable {
        let baseURL: String
        let targetGroupID: Int
        let bearerKey: String
    }

    struct GroupListRequest: Equatable {
        let baseURL: String
        let bearerKey: String
    }

    private let lock = NSLock()
    private var results: [Sub2APICapacityResult]
    private let defaultResult: Sub2APICapacityResult
    private var groupListResults: [Sub2APIGroupListResult]
    private let defaultGroupListResult: Sub2APIGroupListResult
    private let fetchDelayNanoseconds: UInt64?
    private let groupListFetchDelayNanoseconds: UInt64?
    private var storedRequests: [Request] = []
    private var storedGroupListRequests: [GroupListRequest] = []

    var requests: [Request] {
        locked { storedRequests }
    }

    var groupListRequests: [GroupListRequest] {
        locked { storedGroupListRequests }
    }

    init(
        results: [Sub2APICapacityResult] = [],
        defaultResult: Sub2APICapacityResult = .networkError("未配置响应"),
        groupListResults: [Sub2APIGroupListResult] = [],
        defaultGroupListResult: Sub2APIGroupListResult = .networkError("未配置响应"),
        fetchDelayNanoseconds: UInt64? = nil,
        groupListFetchDelayNanoseconds: UInt64? = nil
    ) {
        self.results = results
        self.defaultResult = defaultResult
        self.groupListResults = groupListResults
        self.defaultGroupListResult = defaultGroupListResult
        self.fetchDelayNanoseconds = fetchDelayNanoseconds
        self.groupListFetchDelayNanoseconds = groupListFetchDelayNanoseconds
    }

    func fetchCapacitySummary(baseURL: String, targetGroupID: Int, bearerKey: String) async -> Sub2APICapacityResult {
        let result = locked {
            storedRequests.append(Request(baseURL: baseURL, targetGroupID: targetGroupID, bearerKey: bearerKey))
            guard !results.isEmpty else {
                return defaultResult
            }

            return results.removeFirst()
        }
        if let fetchDelayNanoseconds {
            try? await Task.sleep(nanoseconds: fetchDelayNanoseconds)
        }

        return result
    }

    func fetchCapacityGroups(baseURL: String, bearerKey: String) async -> Sub2APIGroupListResult {
        let result = locked {
            storedGroupListRequests.append(GroupListRequest(baseURL: baseURL, bearerKey: bearerKey))
            guard !groupListResults.isEmpty else {
                return defaultGroupListResult
            }

            return groupListResults.removeFirst()
        }
        if let groupListFetchDelayNanoseconds {
            try? await Task.sleep(nanoseconds: groupListFetchDelayNanoseconds)
        }

        return result
    }

    private func locked<Value>(_ body: () -> Value) -> Value {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

private final class FakeDeckConfigurationStore: DeckConfigurationStoring {
    private let loadedState: DeckGridInteractionState?
    private let loadedBrightnessPercent: Int?
    private(set) var savedStates: [DeckGridInteractionState] = []
    private(set) var savedBrightnessPercents: [Int] = []

    init(
        loadedState: DeckGridInteractionState? = nil,
        loadedBrightnessPercent: Int? = nil
    ) {
        self.loadedState = loadedState
        self.loadedBrightnessPercent = loadedBrightnessPercent
    }

    func loadInteractionState(for layout: DeckGridLayout) -> DeckGridInteractionState? {
        loadedState
    }

    func saveInteractionState(_ state: DeckGridInteractionState, for layout: DeckGridLayout) {
        savedStates.append(state)
    }

    func loadBrightnessPercent() -> Int? {
        loadedBrightnessPercent
    }

    func saveBrightnessPercent(_ percent: Int) {
        savedBrightnessPercents.append(percent)
    }
}

private final class FakeMihoyoGameService: MihoyoGameServicing, @unchecked Sendable {
    struct FetchRequest: Equatable {
        let game: MihoyoGame
        let session: MihoyoLoginSession
    }

    private let lock = NSLock()
    private let createdQRCode: MihoyoQRLoginSession
    private var qrResults: [MihoyoQRCodeStatusResult]
    private var fetchResults: [MihoyoGameStatusResult]
    private let defaultFetchResult: MihoyoGameStatusResult
    private let fetchResultsByAccountID: [String: MihoyoGameStatusResult]
    private let fetchDelayNanoseconds: UInt64?
    private var storedQueryRequests: [MihoyoQRLoginSession] = []
    private var storedFetchRequests: [FetchRequest] = []

    var queryRequests: [MihoyoQRLoginSession] {
        locked { storedQueryRequests }
    }

    var fetchRequests: [FetchRequest] {
        locked { storedFetchRequests }
    }

    init(
        createdQRCode: MihoyoQRLoginSession = MihoyoQRLoginSession(ticket: "ticket", url: "https://example.com/login", deviceID: "device"),
        qrResults: [MihoyoQRCodeStatusResult] = [],
        fetchResults: [MihoyoGameStatusResult] = [],
        defaultFetchResult: MihoyoGameStatusResult = .networkError("未配置响应"),
        fetchResultsByAccountID: [String: MihoyoGameStatusResult] = [:],
        fetchDelayNanoseconds: UInt64? = nil
    ) {
        self.createdQRCode = createdQRCode
        self.qrResults = qrResults
        self.fetchResults = fetchResults
        self.defaultFetchResult = defaultFetchResult
        self.fetchResultsByAccountID = fetchResultsByAccountID
        self.fetchDelayNanoseconds = fetchDelayNanoseconds
    }

    func createQRCodeLogin() async throws -> MihoyoQRLoginSession {
        createdQRCode
    }

    func queryQRCodeLogin(_ session: MihoyoQRLoginSession) async throws -> MihoyoQRCodeStatusResult {
        locked {
            storedQueryRequests.append(session)
            guard !qrResults.isEmpty else {
                return .waitingForScan
            }

            return qrResults.removeFirst()
        }
    }

    func fetchDailyStatus(game: MihoyoGame, session: MihoyoLoginSession) async -> MihoyoGameStatusResult {
        let result = locked {
            storedFetchRequests.append(FetchRequest(game: game, session: session))
            if let result = fetchResultsByAccountID[session.accountID] {
                return result
            }

            guard !fetchResults.isEmpty else {
                return defaultFetchResult
            }

            return fetchResults.removeFirst()
        }

        if let fetchDelayNanoseconds {
            try? await Task.sleep(nanoseconds: fetchDelayNanoseconds)
        }

        return result
    }

    private func locked<Value>(_ body: () -> Value) -> Value {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

private final class FakeMihoyoSessionStore: MihoyoSessionStoring {
    private let loadedSession: MihoyoLoginSession?
    private(set) var savedSessions: [MihoyoLoginSession] = []
    private(set) var clearCount = 0

    init(loadedSession: MihoyoLoginSession? = nil) {
        self.loadedSession = loadedSession
    }

    func loadSession() -> MihoyoLoginSession? {
        loadedSession
    }

    func saveSession(_ session: MihoyoLoginSession) {
        savedSessions.append(session)
    }

    func clearSession() {
        clearCount += 1
    }
}

private final class FakeSingleInstanceLocker: SingleInstanceLocking {
    private var results: [Bool]
    private(set) var requestedIdentifiers: [String] = []

    init(results: [Bool]) {
        self.results = results
    }

    func tryAcquire(identifier: String) -> Bool {
        requestedIdentifiers.append(identifier)
        guard !results.isEmpty else {
            return false
        }

        return results.removeFirst()
    }
}

private final class FakeExistingApplicationLocator: ExistingApplicationLocating {
    struct LookupRequest: Equatable {
        let bundleIdentifier: String
        let latestLaunchDate: Date?
    }

    private var results: [ExistingApplication?]
    private(set) var lookupRequests: [LookupRequest] = []

    init(results: [ExistingApplication?] = []) {
        self.results = results
    }

    func existingApplication(bundleIdentifier: String, launchedBefore latestLaunchDate: Date?) -> ExistingApplication? {
        lookupRequests.append(LookupRequest(
            bundleIdentifier: bundleIdentifier,
            latestLaunchDate: latestLaunchDate
        ))
        guard !results.isEmpty else {
            return nil
        }

        return results.removeFirst()
    }
}

@MainActor
private final class FakeBrightnessAdjuster: BrightnessAdjusting {
    var canAdjustBrightness = true
    private(set) var appliedPercents: [Int] = []

    func adjustBrightness(to percent: Int) {
        appliedPercents.append(percent)
    }
}

@MainActor
private final class FakeFinderFolderOpener: FinderFolderOpening {
    private(set) var openedPaths: [String] = []
    private(set) var openedConfigurations: [DeckKeyOpenFolderConfiguration] = []
    var result: FinderFolderOpenResult = .opened(refreshedConfiguration: nil)

    func openFolder(_ configuration: DeckKeyOpenFolderConfiguration) -> FinderFolderOpenResult {
        openedConfigurations.append(configuration)
        if let path = configuration.path {
            openedPaths.append(path)
        }
        return result
    }
}

@MainActor
private final class FakeFinderFileOpener: FinderFileOpening {
    private(set) var openedPaths: [String] = []
    private(set) var openedConfigurations: [DeckKeyOpenFileConfiguration] = []
    var result: FinderFileOpenResult = .opened(refreshedConfiguration: nil)

    func openFile(_ configuration: DeckKeyOpenFileConfiguration) -> FinderFileOpenResult {
        openedConfigurations.append(configuration)
        if let path = configuration.path {
            openedPaths.append(path)
        }
        return result
    }
}

@MainActor
private final class FakeSMBServerConnector: SMBServerConnecting {
    private(set) var connectedAddresses: [String] = []

    func connect(to address: String) -> Bool {
        connectedAddresses.append(address)
        return true
    }
}

@MainActor
private final class FakeNetFSMounter: NetFSMounting {
    private let status: Int
    private let completionStatus: Int?
    private var pendingCompletion: ((Int) -> Void)?
    private(set) var mountedURLs: [URL] = []

    init(status: Int, completionStatus: Int? = nil) {
        self.status = status
        self.completionStatus = completionStatus
    }

    func mount(url: URL, completion: @escaping (Int) -> Void) -> Int {
        mountedURLs.append(url)
        pendingCompletion = completion
        return status
    }

    func completePendingMount() {
        guard let completionStatus, let pendingCompletion else {
            return
        }

        pendingCompletion(completionStatus)
        self.pendingCompletion = nil
    }
}

@MainActor
private final class FakeSMBURLOpener: SMBURLOpening {
    private(set) var openedURLs: [URL] = []

    func open(_ url: URL) -> Bool {
        openedURLs.append(url)
        return true
    }
}
