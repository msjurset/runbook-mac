import Foundation

/// Manages CLI binary detection, installation from GitHub Releases, and version checking.
@MainActor @Observable
class CLIInstaller {
    var installedVersion: String?
    var latestVersion: String?
    var isUpdateAvailable: Bool { latestVersion != nil && installedVersion != nil && latestVersion != installedVersion }
    var isInstalled: Bool { Self.isCLIInstalled }
    var isDownloading = false
    var error: String?

    nonisolated private static let repo = "msjurset/runbook"
    nonisolated private static let installDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".local/bin").path

    nonisolated static var installPath: String {
        "\(installDir)/runbook"
    }

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
        candidatePaths.contains { FileManager.default.isExecutableFile(atPath: $0) }
    }

    nonisolated static var resolvedPath: String? {
        candidatePaths.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    // MARK: - Version Detection

    func checkInstalledVersion() {
        guard let path = Self.resolvedPath else {
            installedVersion = nil
            return
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["version"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let version = output.replacingOccurrences(of: "runbook ", with: "")
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

    func install() async {
        isDownloading = true
        error = nil

        do {
            let version = try await fetchLatestVersion()
            let assetURL = try await fetchAssetURL(version: version)
            let tempFile = try await download(url: assetURL)
            try extractAndInstall(tarball: tempFile)
            try? FileManager.default.removeItem(at: tempFile)
            isDownloading = false
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

    private nonisolated func extractAndInstall(tarball: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(atPath: Self.installDir, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-xzf", tarball.path, "-C", Self.installDir, "runbook"]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw InstallError.extractFailed
        }

        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: Self.installPath)
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
