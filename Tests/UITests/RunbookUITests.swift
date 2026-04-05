import XCTest

@MainActor
final class RunbookUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    private func waitForSidebar() -> XCUIElement {
        let sidebar = app.outlines["sidebar"]
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5))
        return sidebar
    }

    private func findElement(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    // MARK: - Window & Layout

    func testAppLaunches() throws {
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))
    }

    func testSidebarIsVisible() throws {
        _ = waitForSidebar()
    }

    // MARK: - Runbook Browser

    func testRunbookListShownByDefault() throws {
        let list = findElement("runbookList")
        XCTAssertTrue(list.waitForExistence(timeout: 5))
    }

    func testEmptyDetailOnLaunch() throws {
        let empty = findElement("detail.empty")
        XCTAssertTrue(empty.waitForExistence(timeout: 5))
    }

    // MARK: - Sidebar Navigation

    func testNavigateToHistory() throws {
        let sidebar = waitForSidebar()
        let historyButton = sidebar.buttons["sidebar.history"]
        XCTAssertTrue(historyButton.waitForExistence(timeout: 5))
        historyButton.click()

        let detail = findElement("detail.history")
        XCTAssertTrue(detail.waitForExistence(timeout: 10))
    }

    func testNavigateToSchedules() throws {
        let sidebar = waitForSidebar()
        let schedulesButton = sidebar.buttons["sidebar.schedules"]
        XCTAssertTrue(schedulesButton.waitForExistence(timeout: 5))
        schedulesButton.click()

        let detail = findElement("detail.schedules")
        XCTAssertTrue(detail.waitForExistence(timeout: 10))
    }

    func testNavigateToRepositories() throws {
        let sidebar = waitForSidebar()
        let reposButton = sidebar.buttons["sidebar.repositories"]
        XCTAssertTrue(reposButton.waitForExistence(timeout: 5))
        reposButton.click()

        let detail = findElement("detail.repositories")
        XCTAssertTrue(detail.waitForExistence(timeout: 10))
    }

    // MARK: - Runbook Selection

    func testSelectRunbookFromList() throws {
        let list = findElement("runbookList")
        XCTAssertTrue(list.waitForExistence(timeout: 5))

        let firstRunbook = list.buttons.firstMatch
        if firstRunbook.waitForExistence(timeout: 5) {
            firstRunbook.click()
            let detail = findElement("detail.runbook")
            XCTAssertTrue(detail.waitForExistence(timeout: 5))
        }
    }
}
