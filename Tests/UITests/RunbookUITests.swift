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

    func testEmptyStateShownOnLaunch() throws {
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
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
    }

    func testNavigateToSchedules() throws {
        let sidebar = waitForSidebar()
        let schedulesButton = sidebar.buttons["sidebar.schedules"]
        XCTAssertTrue(schedulesButton.waitForExistence(timeout: 5))
        schedulesButton.click()

        let detail = findElement("detail.schedules")
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
    }

    func testNavigateToRepositories() throws {
        let sidebar = waitForSidebar()
        let reposButton = sidebar.buttons["sidebar.repositories"]
        XCTAssertTrue(reposButton.waitForExistence(timeout: 5))
        reposButton.click()

        let detail = findElement("detail.repositories")
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
    }

    // MARK: - Runbook Selection

    func testSelectRunbookFromSidebar() throws {
        let sidebar = waitForSidebar()
        let firstRunbook = sidebar.cells.element(boundBy: 1).buttons.firstMatch
        if firstRunbook.waitForExistence(timeout: 5) {
            firstRunbook.click()
            let detail = findElement("detail.runbook")
            XCTAssertTrue(detail.waitForExistence(timeout: 5))
        }
    }
}
