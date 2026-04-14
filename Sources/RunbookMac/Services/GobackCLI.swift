import Foundation

/// Bridges to the `goback` CLI binary for credential pre-warming.
enum GobackCLI {
    static var binaryPath: String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/.local/bin/goback",
            "/usr/local/bin/goback",
            "/opt/homebrew/bin/goback",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static var isInstalled: Bool { binaryPath != nil }

    /// Runs `goback auth` to resolve and cache op:// secrets in the keychain.
    /// Returns combined stdout/stderr.
    static func auth() async throws -> String {
        guard let bin = binaryPath else {
            throw NSError(domain: "GobackCLI", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "goback is not installed or not on PATH",
            ])
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: bin)
                process.arguments = ["auth"]

                var env = ProcessInfo.processInfo.environment
                if env["HOME"] == nil {
                    env["HOME"] = FileManager.default.homeDirectoryForCurrentUser.path
                }
                if let path = env["PATH"] {
                    let extras = ["\(env["HOME"]!)/.local/bin", "/opt/homebrew/bin", "/usr/local/bin"]
                    let missing = extras.filter { !path.contains($0) }
                    if !missing.isEmpty {
                        env["PATH"] = (missing + [path]).joined(separator: ":")
                    }
                }
                process.environment = env

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    if process.terminationStatus == 0 {
                        continuation.resume(returning: output)
                    } else {
                        continuation.resume(throwing: NSError(
                            domain: "GobackCLI",
                            code: Int(process.terminationStatus),
                            userInfo: [NSLocalizedDescriptionKey: output.isEmpty ? "goback auth failed (exit \(process.terminationStatus))" : output]
                        ))
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
