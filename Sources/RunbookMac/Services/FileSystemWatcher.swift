import CoreServices
import Foundation

/// Watches a directory tree for changes via FSEvents. The callback fires on
/// the main queue, coalesced with a 0.5s latency so a burst of save events
/// (e.g. an editor's atomic save: create temp → rename → unlink) collapses
/// into a single refresh.
///
/// Used by RunbookStore to pick up YAML edits made outside the app (vim,
/// VS Code, `git pull` of a runbook repo) without forcing the user to hit
/// a Refresh button. Recursive — a new YAML dropped into a nested folder
/// surfaces immediately.
/// `@unchecked Sendable` because the FSEvents callback is C-style and runs
/// on FSEvents' own queue; we only schedule onto the main queue from there
/// and never touch `stream` outside start/stop (which the caller invokes
/// from the main thread).
final class FileSystemWatcher: @unchecked Sendable {
    private let path: String
    private let onChange: () -> Void
    private var stream: FSEventStreamRef?

    init(path: String, onChange: @escaping () -> Void) {
        self.path = path
        self.onChange = onChange
    }

    deinit { stop() }

    func start() {
        guard stream == nil else { return }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let pathsCF = [path] as CFArray

        // kFSEventStreamCreateFlagFileEvents: report file-level changes (not
        // just directory rollups) so we don't miss a single-file edit.
        // kFSEventStreamCreateFlagNoDefer: deliver the first event in a burst
        // immediately rather than waiting out the full latency window.
        let flags = UInt32(
            kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer
        )

        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<FileSystemWatcher>.fromOpaque(info)
                .takeUnretainedValue()
            DispatchQueue.main.async {
                watcher.onChange()
            }
        }

        stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            pathsCF,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            flags
        )

        if let stream {
            FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
            FSEventStreamStart(stream)
        }
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }
}
