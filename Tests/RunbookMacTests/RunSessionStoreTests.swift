import Testing
import Foundation
@testable import RunbookMac

@Suite("RunSessionStore")
@MainActor
struct RunSessionStoreTests {
    @Test func consoleHeightDefaultAndMutation() {
        let store = RunSessionStore()
        
        // Reset consoleHeight in UserDefaults for testing
        UserDefaults.standard.removeObject(forKey: "consoleHeight")
        
        // Default should be 280
        #expect(store.consoleHeight == 280.0)
        
        // Mutating should update value and save to UserDefaults
        store.consoleHeight = 350.0
        #expect(store.consoleHeight == 350.0)
        #expect(UserDefaults.standard.double(forKey: "consoleHeight") == 350.0)
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "consoleHeight")
    }

    @Test func runSessionStoreDefaults() {
        let store = RunSessionStore()
        #expect(store.isExpanded == true)
        #expect(store.sessions.isEmpty)
        #expect(store.current == nil)
    }
}
