import XCTest

@MainActor
final class LuckTabViewUITests: XCTestCase {
    private let app = XCUIApplication()

    override func tearDown() {
        if let testRun, testRun.failureCount > 0 {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        super.tearDown()
    }

    func testAnimatedExpansionAndCollapseRemainUsable() {
        continueAfterFailure = false
        app.launch()
        for destination in ["library", "home", "radio"] {
            assertCompactBar()
            tap(app.buttons["luck.tabs.expand"])
            selectTab(destination)
        }
        assertCompactBar()
        tap(app.buttons["luck.tabs.expand"])
        XCTAssertTrue(app.buttons["luck.tab.radio"].isSelected)
    }

    func testCompactDragCommitsLibraryWithAndWithoutAnimation() {
        for reduceMotion in [true, false] {
            launchDemo(reduceMotion: reduceMotion)
            assertCompactBar()
            let circle = app.buttons["luck.tabs.expand"]
            // NOTE: Hold through expansion so the animated strip reaches its final hit geometry before release.
            circle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.1, thenDragTo: compactLibraryCoordinate(),
                       withVelocity: .slow, thenHoldForDuration: reduceMotion ? 0 : 1)
            assertDestination("Library")
            assertCompactBar()
            tap(circle)
            XCTAssertTrue(app.buttons["luck.tab.library"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["luck.tab.library"].isSelected)
            XCTAssertFalse(app.buttons["luck.tab.home"].isSelected)
            XCTAssertFalse(app.buttons["luck.tab.search"].exists)
        }
    }

    func testExpandedDragCommitsInBothDirectionsAndRightToLeftLayout() {
        for rightToLeft in [false, true] {
            launchDemo(behavior: "Compact on search", rightToLeft: rightToLeft)
            let home = app.buttons["luck.tab.home"]
            let library = app.buttons["luck.tab.library"]
            XCTAssertTrue(home.waitForExistence(timeout: 5))
            XCTAssertTrue(library.waitForExistence(timeout: 5))
            XCTAssertEqual(home.frame.midX > library.frame.midX, rightToLeft)

            home.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.1,
                       thenDragTo: library.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
            assertDestination("Library")
            XCTAssertTrue(library.isSelected)
            XCTAssertFalse(home.isSelected)
            XCTAssertFalse(app.buttons["luck.tabs.expand"].exists)

            library.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.1,
                       thenDragTo: home.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
            assertDestination("Home")
            XCTAssertTrue(home.isSelected)
            XCTAssertFalse(library.isSelected)
        }
    }

    func testReleaseAboveStripCancelsCompactAndExpandedDrags() {
        launchDemo()
        assertCompactBar()
        let outside = compactLibraryCoordinate().withOffset(CGVector(dx: 0, dy: -150))
        // NOTE: The diagonal travels farther horizontally than vertically so the pan recognizes before leaving the strip.
        app.buttons["luck.tabs.expand"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: outside)
        assertDestination("Home")
        let home = app.buttons["luck.tab.home"]
        let library = app.buttons["luck.tab.library"]
        XCTAssertTrue(home.waitForExistence(timeout: 5), "The cancelled compact drag must have expanded the strip")
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        XCTAssertTrue(home.isSelected)
        XCTAssertFalse(library.isSelected)

        home.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1,
                   thenDragTo: library.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                    .withOffset(CGVector(dx: 0, dy: -150)))
        assertDestination("Home")
        XCTAssertTrue(home.isSelected)
        XCTAssertFalse(library.isSelected)

        home.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1,
                   thenDragTo: library.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
        assertDestination("Library")
        assertCompactBar()
    }

    func testSearchDragUsesFiveSlotsAndPreservesQuery() {
        launchDemo(behavior: "Compact on search")
        let home = app.buttons["luck.tab.home"]
        let searchTab = app.buttons["luck.tab.search"]
        XCTAssertTrue(home.waitForExistence(timeout: 5))
        XCTAssertTrue(searchTab.waitForExistence(timeout: 5))
        let library = app.buttons["luck.tab.library"]
        let libraryX = library.frame.midX
        home.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1,
                   thenDragTo: searchTab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
        assertDestination("Search")
        assertCompactBar()
        let search = app.textFields["luck.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        search.typeText("Redlight")

        let circle = app.buttons["luck.tabs.expand"]
        // NOTE: Keep the finger at its original height while expansion dismisses the keyboard.
        let target = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: libraryX - app.frame.minX, dy: circle.frame.midY - app.frame.minY))
        circle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: target)
        assertDestination("Library")
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        XCTAssertTrue(library.isSelected)
        XCTAssertFalse(home.isSelected)
        XCTAssertTrue(searchTab.exists)
        XCTAssertFalse(searchTab.isSelected)
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertTrue(search.waitForNonExistence(timeout: 5))
        selectTab("search")
        assertDestination("Search")
        XCTAssertEqual(search.value as? String, "Redlight")
    }

    func testAccessibilityIndicatorDragsWhileOtherTabsScroll() {
        continueAfterFailure = false
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        tap(app.buttons["luck.tabs.expand"])
        let home = app.buttons["luck.tab.home"]
        let new = app.buttons["luck.tab.new"]
        XCTAssertTrue(new.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(home.frame.width, 150, "This test must exercise the scrolling accessibility layout")
        let origin = app.coordinate(withNormalizedOffset: .zero)
        // NOTE: Target the visible portion of a partially clipped tab.
        let visibleNew = new.frame.intersection(app.frame.insetBy(dx: 24, dy: 0))
        XCTAssertFalse(visibleNew.isNull)
        home.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1,
                   thenDragTo: origin.withOffset(CGVector(dx: visibleNew.midX, dy: visibleNew.midY)))
        assertCompactBar()
        tap(app.buttons["luck.tabs.expand"])
        XCTAssertTrue(new.waitForExistence(timeout: 5))
        XCTAssertTrue(new.isSelected)

        let radio = app.buttons["luck.tab.radio"]
        let visibleRadio = radio.frame.intersection(app.frame.insetBy(dx: 24, dy: 0))
        XCTAssertFalse(visibleRadio.isNull)
        let start = origin.withOffset(CGVector(dx: visibleRadio.midX, dy: visibleRadio.midY))
        let end = origin.withOffset(CGVector(dx: 48, dy: visibleRadio.midY))
        start.press(forDuration: 0.1, thenDragTo: end)
        XCTAssertTrue(app.buttons["luck.tab.library"].isHittable)
        XCTAssertTrue(new.isSelected, "Scrolling from an unselected tab must not commit a selection")
        XCTAssertFalse(app.buttons["luck.tabs.expand"].exists)
    }

    func testIdleCollapseMovesBeforeReachingCompactPosition() {
        continueAfterFailure = false
        app.launch()
        let expand = app.buttons["luck.tabs.expand"]
        XCTAssertTrue(expand.waitForExistence(timeout: 5))
        let compactX = expand.frame.midX
        editSettings { tap(app.switches["Slow animations"]) }
        tap(expand)
        // NOTE: The regression occurs after the opening timeline has finished, not during interruption.
        Thread.sleep(forTimeInterval: 20)
        selectTab("library")
        XCTAssertTrue(expand.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(expand.frame.midX, compactX + 8,
                             "Collapse must start from the expanded geometry instead of fading in at rest")
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            abs(expand.frame.midX - compactX) < 2
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 20), .completed)
    }

    func testSelectionBindingAndIndependentDestinationState() {
        launchDemo(behavior: "Compact on search")
        let favorites = app.buttons["demo.favorites"]
        tap(favorites)
        tap(favorites)
        XCTAssertEqual(favorites.label, "Favorites: 2")

        selectTab("new")
        XCTAssertEqual(favorites.label, "Favorites: 0")
        tap(favorites)

        editSettings {
            choose("Selected tab", option: "Radio")
        }
        assertDestination("Radio")
        XCTAssertTrue(app.buttons["luck.tab.radio"].isSelected)
        XCTAssertEqual(favorites.label, "Favorites: 0")

        selectTab("home")
        XCTAssertEqual(favorites.label, "Favorites: 2")
        tap(app.buttons["Heaven Takes You Home"].firstMatch)
        assertDestination("Heaven Takes You Home")
        selectTab("new")
        assertDestination("New")
        XCTAssertEqual(favorites.label, "Favorites: 1")
        selectTab("home")
        assertDestination("Heaven Takes You Home")
    }

    func testSearchFocusQueryRetentionAndHiddenControls() {
        launchDemo()
        let search = app.textFields["luck.search"]
        assertCompactBar()
        tap(search)
        assertDestination("Search")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        search.typeText("Redlight")
        XCTAssertEqual(search.value as? String, "Redlight")
        XCTAssertTrue(app.buttons["Redlight"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Heaven Takes You Home"].exists)

        tap(app.buttons["luck.tabs.expand"])
        XCTAssertTrue(search.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["luck.tabs.expand"].waitForNonExistence(timeout: 5))
        selectTab("search")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(search.value as? String, "Redlight")
        tap(app.buttons["luck.tabs.expand"])
        selectTab("home")
        assertDestination("Home")
        assertCompactBar()
        XCTAssertEqual(search.value as? String, "Redlight")

        tap(app.buttons["luck.tabs.expand"])
        XCTAssertTrue(app.buttons["luck.tab.home"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["luck.tab.search"].exists)
        selectTab("library")
        assertDestination("Library")
        tap(search)
        assertDestination("Search")
        XCTAssertEqual(search.value as? String, "Redlight")
        tap(app.buttons["Clear search"])
        XCTAssertTrue(app.buttons["Heaven Takes You Home"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Clear search"].exists)
    }

    func testRemovingSelectedSearchAndPlayerKeepsTabsUsable() {
        launchDemo()
        tap(app.buttons["demo.favorites"])
        tap(app.buttons["Play"])
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 5))
        tap(app.textFields["luck.search"])
        assertDestination("Search")

        editSettings {
            tap(app.switches["Search tab"])
            tap(app.switches["Player accessory"])
        }
        assertDestination("Home")
        XCTAssertEqual(app.buttons["demo.favorites"].label, "Favorites: 1")
        XCTAssertTrue(app.textFields["luck.search"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Play"].exists)
        XCTAssertFalse(app.buttons["Pause"].exists)
        XCTAssertFalse(app.buttons["Next track"].exists)
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))

        tap(app.buttons["luck.tabs.expand"])
        XCTAssertFalse(app.buttons["luck.tab.search"].exists)
        selectTab("library")
        assertDestination("Library")
        tap(app.buttons["luck.tabs.expand"])
        selectTab("home")
        assertDestination("Home")
        XCTAssertEqual(app.buttons["demo.favorites"].label, "Favorites: 1")

        editSettings {
            tap(app.switches["Search tab"])
            tap(app.switches["Player accessory"])
        }
        XCTAssertTrue(app.textFields["luck.search"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 5))
    }

    func testScrollCompactionAndTabSelectionInRightToLeftLayout() {
        launchDemo(behavior: "Compact on scroll", rightToLeft: true)
        XCTAssertTrue(app.textFields["luck.search"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.buttons["luck.tabs.expand"].exists)
        let home = app.buttons["luck.tab.home"]
        let library = app.buttons["luck.tab.library"]
        XCTAssertTrue(home.waitForExistence(timeout: 5))
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(home.frame.midX, library.frame.midX)

        app.collectionViews.firstMatch.swipeUp()
        assertCompactBar()
        tap(app.buttons["luck.tabs.expand"])
        app.collectionViews.firstMatch.swipeUp()
        assertCompactBar()
        app.collectionViews.firstMatch.swipeDown()
        XCTAssertTrue(home.waitForExistence(timeout: 5))
        selectTab("library")
        assertDestination("Library")
        XCTAssertTrue(app.buttons["luck.tab.library"].isSelected)
        tap(app.buttons["demo.favorites"])
        selectTab("home")
        assertDestination("Home")
        selectTab("library")
        XCTAssertEqual(app.buttons["demo.favorites"].label, "Favorites: 1")
    }

    func testLastRowClearsControlsAndBottomBounceKeepsBarCompact() {
        launchDemo(behavior: "Compact on scroll")
        let list = app.collectionViews.firstMatch
        let lastRow = list.cells.containing(.staticText, identifier: "demo.end").firstMatch
        let player = app.buttons["Play"]
        for _ in 0..<12 {
            if lastRow.exists && lastRow.isHittable && lastRow.frame.maxY <= player.frame.minY - 4 { break }
            list.swipeUp()
        }
        XCTAssertTrue(lastRow.exists)
        XCTAssertLessThanOrEqual(lastRow.frame.maxY, player.frame.minY - 4,
                                 "The last row must scroll fully above the floating player")
        assertCompactBar()
        list.swipeUp()
        assertCompactBar()
        tap(app.buttons["luck.tabs.expand"])
        XCTAssertTrue(app.buttons["luck.tab.home"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["luck.tabs.expand"].exists)
    }

    private func launchDemo(behavior: String? = nil, rightToLeft: Bool = false, reduceMotion: Bool = true) {
        continueAfterFailure = false
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        editSettings {
            tap(app.switches["Live content"])
            if reduceMotion { tap(app.switches["Reduce motion"]) }
            if let behavior { choose("Bar behavior", option: behavior) }
            if rightToLeft { tap(app.switches["Right to left"]) }
        }
        assertDestination("Home")
    }

    private func editSettings(_ edit: () -> Void) {
        tap(app.buttons["Experiment settings"])
        XCTAssertTrue(app.switches["Live content"].waitForExistence(timeout: 5))
        edit()
        tap(app.buttons["Done"])
        XCTAssertTrue(app.switches["Live content"].waitForNonExistence(timeout: 5))
    }

    private func choose(_ picker: String, option: String) {
        tap(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", picker)).firstMatch)
        tap(app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@",
                                            option, "luck.tab.\(option.lowercased())")).firstMatch)
    }

    private func selectTab(_ id: String) {
        tap(app.buttons["luck.tab.\(id)"])
    }

    private func compactLibraryCoordinate() -> XCUICoordinate {
        // NOTE: Compact tabs have no accessible frames; target their expanded slots inside the public bar's margins.
        let width = min(app.frame.width - 48, 600)
        let cellWidth = (width - 8) / 4
        let x = app.frame.width / 2 - width / 2 + 4 + 3.5 * cellWidth
        let y = app.buttons["luck.tabs.expand"].frame.midY - app.frame.minY
        return app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y))
    }

    private func assertDestination(_ title: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5),
                      "Expected the \(title) destination", file: file, line: line)
    }

    private func assertCompactBar(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.buttons["luck.tabs.expand"].waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(app.buttons["luck.tab.home"].waitForNonExistence(timeout: 5), file: file, line: line)
        XCTAssertFalse(app.buttons["luck.tab.new"].exists, file: file, line: line)
        XCTAssertFalse(app.buttons["luck.tab.radio"].exists, file: file, line: line)
        XCTAssertFalse(app.buttons["luck.tab.library"].exists, file: file, line: line)
        XCTAssertFalse(app.buttons["luck.tab.search"].exists, file: file, line: line)
    }

    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true"),
                                             object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed,
                       "Expected a visible, tappable control: \(element)", file: file, line: line)
        if element.elementType == .switch {
            // NOTE: SwiftUI exposes the labelled row and its actual switch separately on iOS 18.
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        } else {
            element.tap()
        }
    }
}
