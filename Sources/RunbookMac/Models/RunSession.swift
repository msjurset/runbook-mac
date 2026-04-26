import Foundation

/// A single in-flight or recently-completed runbook execution owned by
/// RunSessionStore. The console tray renders one of these.
struct RunSession: Identifiable {
    enum State: Equatable {
        case running
        case succeeded
        case failed(String)
        case cancelled

        var isTerminal: Bool {
            switch self {
            case .running: false
            default: true
            }
        }
    }

    let id = UUID()
    let runbookName: String
    /// Mutable so a Retry can flip dry/real without spawning a new session.
    var dryRun: Bool
    /// Captured at start so the Retry button can rerun with identical args.
    /// Mutable so a "Retry with different inputs…" flow can update them.
    var vars: [String: String]
    /// Mutable so an in-place Retry can reset the start time without
    /// minting a new session id (which would spawn a new tab).
    var startedAt: Date
    var endedAt: Date?
    var output: [String] = []
    var state: State = .running

    /// Human-readable elapsed or total duration string.
    func elapsed(now: Date = Date()) -> String {
        let end = endedAt ?? now
        let seconds = Int(end.timeIntervalSince(startedAt))
        if seconds < 60 { return "\(seconds)s" }
        let m = seconds / 60
        let s = seconds % 60
        if m < 60 { return s > 0 ? "\(m)m \(s)s" : "\(m)m" }
        let h = m / 60
        let rm = m % 60
        return rm > 0 ? "\(h)h \(rm)m" : "\(h)h"
    }
}
