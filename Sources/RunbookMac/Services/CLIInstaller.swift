import Foundation

/// Manages CLI binary detection, installation from GitHub Releases, and version checking.
@MainActor @Observable
class CLIInstaller {
    var installedVersion: String?
    var latestVersion: String?
    /// True only when the published release is strictly NEWER than what's
    /// installed locally. Plain string-inequality breaks when the user has
    /// an ahead-of-release local build (e.g. installed=1.7.1, latest=1.7.0)
    /// — that's a downgrade, not an update. Dev/unversioned builds are
    /// treated as updateable so users running a stale `make deploy` aren't
    /// stuck without a path to the canonical release.
    var isUpdateAvailable: Bool {
        guard let latest = latestVersion, let installed = installedVersion else { return false }
        if installed == "dev" { return true }
        return Self.compareSemver(latest, installed) > 0
    }

    /// Three-way semver-ish compare. Splits on `.`, parses each chunk as an
    /// Int, compares left-to-right; shorter-but-equal-prefix versions sort
    /// older. Doesn't try to parse pre-release tags (`-alpha.1`) — none of
    /// our releases use them. Returns -1, 0, or 1.
    nonisolated static func compareSemver(_ a: String, _ b: String) -> Int {
        let strip: (String) -> String = { s in
            s.hasPrefix("v") ? String(s.dropFirst()) : s
        }
        let aTokens = strip(a).split(separator: ".").map { Int($0) ?? 0 }
        let bTokens = strip(b).split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(aTokens.count, bTokens.count) {
            let av = i < aTokens.count ? aTokens[i] : 0
            let bv = i < bTokens.count ? bTokens[i] : 0
            if av != bv { return av < bv ? -1 : 1 }
        }
        return 0
    }
    var isInstalled: Bool { Self.isCLIInstalled }
    var isDownloading = false
    var error: String?

    nonisolated private static let repo = "msjurset/runbook"

    static var defaultInstallDir: String {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin").path
    }

    /// Fallback locations searched only if the user's interactive shell can't
    /// resolve `runbook` for us (broken .zshrc, etc.). Order doesn't dictate
    /// version precedence — the shell-PATH path from `command -v` always
    /// wins when available.
    nonisolated static var candidatePaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/.local/bin/runbook",
            "\(home)/go/bin/runbook",
            "/usr/local/bin/runbook",
            "/opt/homebrew/bin/runbook",
        ]
    }

    nonisolated static var isCLIInstalled: Bool {
        resolvedPath != nil
    }

    /// Path of the `runbook` binary the user's shell would actually invoke.
    /// Resolved via `command -v runbook` in an interactive shell so it
    /// honors the user's PATH order — a launched .app otherwise inherits a
    /// stripped PATH (usually `/usr/bin:/bin:/usr/sbin:/sbin`) and the
    /// in-app installer would show "v1.7.0 from /opt/homebrew/bin" while
    /// the user's terminal still resolves to a `dev` build at
    /// `~/.local/bin/runbook`. Falls back to the candidatePaths scan only if
    /// the shell lookup fails.
    nonisolated static var resolvedPath: String? {
        ResolvedPathCache.get()
    }

    /// Force a re-read of the binary path. Call after install/uninstall —
    /// otherwise the cache holds the previous answer.
    nonisolated static func refreshResolvedPath() {
        ResolvedPathCache.invalidate()
    }

    /// Check if a directory is in the user's PATH.
    nonisolated static func isInPATH(_ dir: String) -> Bool {
        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        return path.components(separatedBy: ":").contains(dir)
    }

    // MARK: - Version Detection

    func checkInstalledVersion() {
        guard let path = Self.resolvedPath else {
            installedVersion = nil
            return
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["--version"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            // Output format: "runbook version X.Y.Z" or "runbook version dev"
            var version = output
            for prefix in ["runbook version ", "runbook "] {
                if version.hasPrefix(prefix) {
                    version = String(version.dropFirst(prefix.count))
                    break
                }
            }
            installedVersion = version.isEmpty ? nil : version
        } catch {
            installedVersion = nil
        }
    }

    func checkLatestVersion() async {
        let url = URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest")!
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let tagName = json["tag_name"] as? String {
                let version = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
                latestVersion = version
            }
        } catch {
            // Silently fail
        }
    }

    func shouldCheckForUpdate() -> Bool {
        let key = "lastCLIUpdateCheck"
        let lastCheck = UserDefaults.standard.double(forKey: key)
        let now = Date().timeIntervalSince1970
        if now - lastCheck < 86400 { return false }
        UserDefaults.standard.set(now, forKey: key)
        return true
    }

    // MARK: - Installation

    func install(to installDir: String? = nil) async {
        isDownloading = true
        error = nil

        let targetDir = installDir ?? Self.defaultInstallDir

        do {
            let version = try await fetchLatestVersion()
            let assetURL = try await fetchAssetURL(version: version)
            let tempFile = try await download(url: assetURL)
            try extractAndInstall(tarball: tempFile, installDir: targetDir)
            try? FileManager.default.removeItem(at: tempFile)
            isDownloading = false
            // The shell-PATH cache is now stale — a new binary appeared at a
            // path that may or may not be the one currently picked up by
            // `command -v`. Drop the cache so the next read is fresh.
            Self.refreshResolvedPath()
            checkInstalledVersion()
        } catch {
            isDownloading = false
            self.error = error.localizedDescription
        }
    }

    private func fetchLatestVersion() async throws -> String {
        let url = URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest")!
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tagName = json["tag_name"] as? String else {
            throw InstallError.noRelease
        }
        return tagName
    }

    private nonisolated func fetchAssetURL(version: String) async throws -> URL {
        let arch = machineArchitecture()
        let versionNum = version.hasPrefix("v") ? String(version.dropFirst()) : version
        let assetName = "runbook-\(versionNum)-darwin-\(arch).tar.gz"

        let url = URL(string: "https://api.github.com/repos/\(Self.repo)/releases/tags/\(version)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let assets = json["assets"] as? [[String: Any]] else {
            throw InstallError.noAssets
        }

        guard let asset = assets.first(where: { ($0["name"] as? String) == assetName }),
              let downloadURL = asset["browser_download_url"] as? String,
              let url = URL(string: downloadURL) else {
            throw InstallError.noMatchingAsset(assetName)
        }
        return url
    }

    private nonisolated func download(url: URL) async throws -> URL {
        let (tempURL, response) = try await URLSession.shared.download(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw InstallError.downloadFailed
        }
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent("runbook-download.tar.gz")
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tempURL, to: dest)
        return dest
    }

    private nonisolated func extractAndInstall(tarball: URL, installDir: String) throws {
        let fm = FileManager.default

        // Create install directory
        try fm.createDirectory(atPath: installDir, withIntermediateDirectories: true)

        // Extract everything to a temp directory first
        let tempDir = fm.temporaryDirectory.appendingPathComponent("runbook-extract-\(UUID().uuidString)")
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }

        let tarProcess = Process()
        tarProcess.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        tarProcess.arguments = ["-xzf", tarball.path, "-C", tempDir.path]
        try tarProcess.run()
        tarProcess.waitUntilExit()
        guard tarProcess.terminationStatus == 0 else {
            throw InstallError.extractFailed
        }

        // Install binary
        let binaryPath = installDir + "/runbook"
        if fm.fileExists(atPath: binaryPath) {
            try fm.removeItem(atPath: binaryPath)
        }
        try fm.copyItem(atPath: tempDir.appendingPathComponent("runbook").path, toPath: binaryPath)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binaryPath)

        // Install man page (best-effort)
        let manSrc = tempDir.appendingPathComponent("runbook.1").path
        if fm.fileExists(atPath: manSrc) {
            let manDir = "/usr/local/share/man/man1"
            try? fm.createDirectory(atPath: manDir, withIntermediateDirectories: true)
            let manDest = manDir + "/runbook.1"
            try? fm.removeItem(atPath: manDest)
            try? fm.copyItem(atPath: manSrc, toPath: manDest)
        }

        // Install zsh completions (best-effort)
        let compSrc = tempDir.appendingPathComponent("_runbook").path
        if fm.fileExists(atPath: compSrc) {
            // Try oh-my-zsh first, then standard zsh site-functions
            let compDirs = [
                FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".oh-my-zsh/custom/completions").path,
                "/usr/local/share/zsh/site-functions",
                "/opt/homebrew/share/zsh/site-functions",
            ]
            for dir in compDirs {
                if fm.fileExists(atPath: (dir as NSString).deletingLastPathComponent) {
                    try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
                    let dest = dir + "/_runbook"
                    try? fm.removeItem(atPath: dest)
                    try? fm.copyItem(atPath: compSrc, toPath: dest)
                    break
                }
            }
        }
    }

    private nonisolated func machineArchitecture() -> String {
        var sysinfo = utsname()
        uname(&sysinfo)
        let machine = withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        return machine == "arm64" ? "arm64" : "amd64"
    }

    /// Static cache for the shell-PATH resolution of `runbook`. The lookup
    /// spawns an interactive shell — cheap, but enough that we don't want to
    /// run it on every SwiftUI re-render. NSLock-guarded so SettingsView's
    /// renders and async install handlers can both read safely.
    private enum ResolvedPathCache {
        nonisolated(unsafe) private static var value: String?? = nil
        private static let lock = NSLock()

        static func get() -> String? {
            lock.lock()
            if let cached = value {
                lock.unlock()
                return cached
            }
            lock.unlock()
            // Lookup outside the lock to avoid holding it across a process
            // spawn.
            let resolved = lookup()
            lock.lock()
            // If another thread populated the cache while we were looking,
            // prefer the existing value (avoids racing two shells).
            if value == nil { value = .some(resolved) }
            let result = value!
            lock.unlock()
            return result
        }

        static func invalidate() {
            lock.lock()
            value = nil
            lock.unlock()
        }

        private static func lookup() -> String? {
            // First try the user's interactive shell — that's whatever
            // `which runbook` would print in their terminal, which respects
            // PATH order set by .zshrc / .bash_profile / etc.
            if let p = pathFromUserShell(),
               FileManager.default.isExecutableFile(atPath: p) {
                return p
            }
            // Fallback only if the shell lookup fails (broken init, no
            // shell, sandboxing). Order is best-effort.
            return CLIInstaller.candidatePaths.first {
                FileManager.default.isExecutableFile(atPath: $0)
            }
        }

        private static func pathFromUserShell() -> String? {
            // SHELL is set by launchd from the user's loginwindow record;
            // default to zsh on modern macOS.
            let shellPath = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
            let process = Process()
            process.executableURL = URL(fileURLWithPath: shellPath)
            // -i loads the user's interactive init (.zshrc, etc.) so PATH
            // mods done there are honored. `command -v` is a POSIX builtin
            // that prints the resolved path to stdout, exit 0 on success.
            process.arguments = ["-i", "-c", "command -v runbook"]
            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe
            do {
                try process.run()
            } catch {
                return nil
            }
            // Bound on a slow shell init. 2s is generous for a normal
            // .zshrc; if it exceeds that we kill the child and fall back.
            let group = DispatchGroup()
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                process.waitUntilExit()
                group.leave()
            }
            if group.wait(timeout: .now() + 2.0) == .timedOut {
                process.terminate()
                return nil
            }
            guard process.terminationStatus == 0 else { return nil }
            let data = outPipe.fileHandleForReading.readDataToEndOfFile()
            let raw = String(data: data, encoding: .utf8) ?? ""
            // Some interactive shells emit greeting/prompt junk to stdout;
            // pick the LAST line that's an absolute path ending in /runbook.
            for line in raw.components(separatedBy: "\n").reversed() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("/") && trimmed.hasSuffix("/runbook") {
                    return trimmed
                }
            }
            return nil
        }
    }

    enum InstallError: LocalizedError {
        case noRelease
        case noAssets
        case noMatchingAsset(String)
        case downloadFailed
        case extractFailed

        var errorDescription: String? {
            switch self {
            case .noRelease: return "No releases found on GitHub"
            case .noAssets: return "Release has no downloadable assets"
            case .noMatchingAsset(let name): return "No asset matching \(name) — release may still be building"
            case .downloadFailed: return "Download failed"
            case .extractFailed: return "Failed to extract the binary"
            }
        }
    }
}
