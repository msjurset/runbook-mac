import Testing
import Foundation
@testable import RunbookMac

@Suite("RunbookStore")
struct RunbookStoreTests {
    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("runbook-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func writeYAML(_ content: String, to dir: URL, filename: String) throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try content.write(to: dir.appendingPathComponent(filename), atomically: true, encoding: .utf8)
    }

    private func makeStore(booksDir: URL) throws -> RunbookStore {
        let base = booksDir.deletingLastPathComponent()
        let historyDir = base.appendingPathComponent("history")
        let pinnedFile = base.appendingPathComponent("pinned.json")
        try FileManager.default.createDirectory(at: historyDir, withIntermediateDirectories: true)
        return RunbookStore(booksDir: booksDir, historyDir: historyDir, pinnedFile: pinnedFile)
    }

    private func cleanup(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir.deletingLastPathComponent())
    }

    // MARK: - Discovery

    @Test func discoverRunbooks() throws {
        let base = try makeTempDir()
        let booksDir = base.appendingPathComponent("books")
        defer { cleanup(booksDir) }

        try writeYAML("name: alpha\nsteps:\n  - name: s1\n    type: shell\n    shell:\n      command: echo hi", to: booksDir, filename: "alpha.yaml")
        try writeYAML("name: beta\nsteps:\n  - name: s1\n    type: shell\n    shell:\n      command: echo hi", to: booksDir, filename: "beta.yaml")

        let store = try makeStore(booksDir: booksDir)
        store.loadAll()

        #expect(store.runbooks.count == 2)
        #expect(store.runbooks[0].name == "alpha")
        #expect(store.runbooks[1].name == "beta")
    }

    @Test func discoverSubdirectories() throws {
        let base = try makeTempDir()
        let booksDir = base.appendingPathComponent("books")
        let subDir = booksDir.appendingPathComponent("repo/system")
        defer { cleanup(booksDir) }

        try writeYAML("name: local\nsteps:\n  - name: s1\n    type: shell\n    shell:\n      command: echo hi", to: booksDir, filename: "local.yaml")
        try writeYAML("name: remote\nsteps:\n  - name: s1\n    type: shell\n    shell:\n      command: echo hi", to: subDir, filename: "remote.yaml")

        let store = try makeStore(booksDir: booksDir)
        store.loadAll()

        #expect(store.runbooks.count == 2)
        #expect(store.runbooks.contains { $0.name == "local" })
        #expect(store.runbooks.contains { $0.name == "remote" })
    }

    @Test func deduplicatePreferShallowerPath() throws {
        let base = try makeTempDir()
        let booksDir = base.appendingPathComponent("books")
        let subDir = booksDir.appendingPathComponent("repo/system")
        defer { cleanup(booksDir) }

        try writeYAML("name: deploy\ndescription: local\nsteps:\n  - name: s1\n    type: shell\n    shell:\n      command: echo local", to: booksDir, filename: "deploy.yaml")
        try writeYAML("name: deploy\ndescription: remote\nsteps:\n  - name: s1\n    type: shell\n    shell:\n      command: echo remote", to: subDir, filename: "deploy.yaml")

        let store = try makeStore(booksDir: booksDir)
        store.loadAll()

        #expect(store.runbooks.count == 1)
        #expect(store.runbooks[0].description == "local")
    }

    // MARK: - Template Separation

    @Test func templatesDiscoveredSeparately() throws {
        let base = try makeTempDir()
        let booksDir = base.appendingPathComponent("books")
        let templatesDir = booksDir.appendingPathComponent("repo/templates")
        defer { cleanup(booksDir) }

        try writeYAML("name: real\nsteps:\n  - name: s1\n    type: shell\n    shell:\n      command: echo hi", to: booksDir, filename: "real.yaml")
        try writeYAML("name: tmpl\nsteps:\n  - name: s1\n    type: shell\n    shell:\n      command: echo hi", to: templatesDir, filename: "tmpl.yaml")

        let store = try makeStore(booksDir: booksDir)
        store.loadAll()

        #expect(store.runbooks.count == 1)
        #expect(store.runbooks[0].name == "real")
        #expect(store.templates.count == 1)
        #expect(store.templates[0].name == "tmpl")
    }

    @Test func templatesNotInRunbookList() throws {
        let base = try makeTempDir()
        let booksDir = base.appendingPathComponent("books")
        let templatesDir = booksDir.appendingPathComponent("repo/templates")
        defer { cleanup(booksDir) }

        try writeYAML("name: ssh-basic\nsteps:\n  - name: s1\n    type: shell\n    shell:\n      command: echo hi", to: templatesDir, filename: "ssh-basic.yaml")

        let store = try makeStore(booksDir: booksDir)
        store.loadAll()

        #expect(store.runbooks.isEmpty)
        #expect(store.templates.count == 1)
    }

    // MARK: - Pinning

    @Test func pinAndUnpin() throws {
        let base = try makeTempDir()
        let booksDir = base.appendingPathComponent("books")
        defer { cleanup(booksDir) }

        try writeYAML("name: alpha\nsteps:\n  - name: s1\n    type: shell\n    shell:\n      command: echo hi", to: booksDir, filename: "alpha.yaml")

        let store = try makeStore(booksDir: booksDir)
        store.loadAll()

        #expect(!store.isPinned(store.runbooks[0]))

        store.togglePin(store.runbooks[0])
        #expect(store.isPinned(store.runbooks[0]))

        store.togglePin(store.runbooks[0])
        #expect(!store.isPinned(store.runbooks[0]))
    }

    @Test func pinnedPersistsAcrossInstances() throws {
        let base = try makeTempDir()
        let booksDir = base.appendingPathComponent("books")
        let historyDir = base.appendingPathComponent("history")
        let pinnedFile = base.appendingPathComponent("pinned.json")
        defer { cleanup(booksDir) }

        try FileManager.default.createDirectory(at: historyDir, withIntermediateDirectories: true)
        try writeYAML("name: alpha\nsteps:\n  - name: s1\n    type: shell\n    shell:\n      command: echo hi", to: booksDir, filename: "alpha.yaml")

        let store1 = RunbookStore(booksDir: booksDir, historyDir: historyDir, pinnedFile: pinnedFile)
        store1.loadAll()
        store1.togglePin(store1.runbooks[0])

        let store2 = RunbookStore(booksDir: booksDir, historyDir: historyDir, pinnedFile: pinnedFile)
        store2.loadAll()
        #expect(store2.isPinned(store2.runbooks[0]))
    }

    // MARK: - CRUD

    @Test func saveAndLoadRawYAML() throws {
        let base = try makeTempDir()
        let booksDir = base.appendingPathComponent("books")
        defer { cleanup(booksDir) }

        let store = try makeStore(booksDir: booksDir)
        let yaml = "name: test\nsteps:\n  - name: s1\n    type: shell\n    shell:\n      command: echo hi"
        try store.saveRaw(yaml, to: "test.yaml")
        store.loadAll()

        #expect(store.runbooks.count == 1)
        #expect(store.runbooks[0].name == "test")

        let raw = store.readRawYAML(for: store.runbooks[0])
        #expect(raw == yaml)
    }

    @Test func deleteRunbook() throws {
        let base = try makeTempDir()
        let booksDir = base.appendingPathComponent("books")
        defer { cleanup(booksDir) }

        let store = try makeStore(booksDir: booksDir)
        try store.saveRaw("name: doomed\nsteps:\n  - name: s1\n    type: shell\n    shell:\n      command: echo bye", to: "doomed.yaml")
        store.loadAll()
        #expect(store.runbooks.count == 1)

        try store.delete(store.runbooks[0])
        store.loadAll()
        #expect(store.runbooks.isEmpty)
    }

    // MARK: - Empty / Missing

    @Test func emptyDirectoryReturnsNoRunbooks() throws {
        let base = try makeTempDir()
        let booksDir = base.appendingPathComponent("books")
        defer { cleanup(booksDir) }
        try FileManager.default.createDirectory(at: booksDir, withIntermediateDirectories: true)

        let store = try makeStore(booksDir: booksDir)
        store.loadAll()

        #expect(store.runbooks.isEmpty)
        #expect(store.templates.isEmpty)
    }

    @Test func invalidYAMLSkipped() throws {
        let base = try makeTempDir()
        let booksDir = base.appendingPathComponent("books")
        defer { cleanup(booksDir) }

        try writeYAML("name: good\nsteps:\n  - name: s1\n    type: shell\n    shell:\n      command: echo hi", to: booksDir, filename: "good.yaml")
        try writeYAML("this is not valid yaml: [[[", to: booksDir, filename: "bad.yaml")

        let store = try makeStore(booksDir: booksDir)
        store.loadAll()

        #expect(store.runbooks.count == 1)
        #expect(store.runbooks[0].name == "good")
    }
}
