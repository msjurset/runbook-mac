import Testing
@testable import RunbookMac

@Suite("Diff Algorithm")
struct DiffTests {
    @Test func identicalInputs() {
        let diff = computeDiff(original: "a\nb\nc", modified: "a\nb\nc")
        #expect(diff.allSatisfy { $0.kind == .unchanged })
        #expect(diff.count == 3)
    }

    @Test func emptyOriginal() {
        let diff = computeDiff(original: "", modified: "a\nb")
        let added = diff.filter { $0.kind == .added }
        #expect(added.count == 2)
    }

    @Test func emptyModified() {
        let diff = computeDiff(original: "a\nb", modified: "")
        let removed = diff.filter { $0.kind == .removed }
        #expect(removed.count == 2)
    }

    @Test func bothEmpty() {
        let diff = computeDiff(original: "", modified: "")
        #expect(diff.count == 1) // one empty unchanged line
        #expect(diff[0].kind == .unchanged)
    }

    @Test func singleLineAdded() {
        let diff = computeDiff(original: "a\nc", modified: "a\nb\nc")
        #expect(diff.count == 3)
        #expect(diff[0].kind == .unchanged)
        #expect(diff[0].text == "a")
        #expect(diff[1].kind == .added)
        #expect(diff[1].text == "b")
        #expect(diff[2].kind == .unchanged)
        #expect(diff[2].text == "c")
    }

    @Test func singleLineRemoved() {
        let diff = computeDiff(original: "a\nb\nc", modified: "a\nc")
        #expect(diff.count == 3)
        #expect(diff[0].kind == .unchanged)
        #expect(diff[1].kind == .removed)
        #expect(diff[1].text == "b")
        #expect(diff[2].kind == .unchanged)
    }

    @Test func lineModified() {
        let diff = computeDiff(original: "a\nb\nc", modified: "a\nB\nc")
        // Modified line shows as removed + added
        let removed = diff.filter { $0.kind == .removed }
        let added = diff.filter { $0.kind == .added }
        #expect(removed.count == 1)
        #expect(removed[0].text == "b")
        #expect(added.count == 1)
        #expect(added[0].text == "B")
    }

    @Test func multipleChanges() {
        let diff = computeDiff(
            original: "header\nold1\nold2\nfooter",
            modified: "header\nnew1\nfooter\nextra"
        )
        let unchanged = diff.filter { $0.kind == .unchanged }
        #expect(unchanged.count == 2) // header + footer
    }

    @Test func diffLinePrefixes() {
        let added = DiffLine(kind: .added, text: "new")
        let removed = DiffLine(kind: .removed, text: "old")
        let unchanged = DiffLine(kind: .unchanged, text: "same")

        #expect(added.prefix == "+")
        #expect(removed.prefix == "-")
        #expect(unchanged.prefix == " ")
    }
}
