import Foundation

/// Bridges to the `runbook` CLI binary for execution and management.
actor RunbookCLI {
    static let shared = RunbookCLI()

    private var binaryPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/.local/bin/runbook",
            "/usr/local/bin/runbook",
            "/opt/homebrew/bin/runbook",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
            ?? "runbook"
    }

    /// Run a runbook by name, streaming output line by line.
    func run(name: String, vars: [String: String] = [:], onOutput: @escaping @Sendable (String) -> Void) async throws -> Bool {
        var args = ["run", "--no-tui", "--yes", name]
        for (k, v) in vars {
            args += ["--var", "\(k)=\(v)"]
        }
        return try await execute(args: args, onOutput: onOutput)
    }

    /// List runbook names.
    func listNames() async throws -> [String] {
        let output = try await captureOutput(args: ["completion-names"])
        return output.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
    }

    /// Validate a runbook.
    func validate(nameOrPath: String) async throws -> String {
        try await captureOutput(args: ["validate", nameOrPath])
    }

    /// Get cron entries.
    func cronList() async throws -> String {
        try await captureOutput(args: ["cron", "list"])
    }

    /// Add a cron entry.
    func cronAdd(name: String, schedule: String) async throws -> String {
        try await captureOutput(args: ["cron", "add", name, schedule])
    }

    /// Remove a cron entry.
    func cronRemove(name: String, schedule: String? = nil) async throws -> String {
        var args = ["cron", "remove", name]
        if let schedule { args.append(schedule) }
        return try await captureOutput(args: args)
    }

    /// Pull a repo or file.
    func pull(url: String) async throws -> String {
        try await captureOutput(args: ["pull", url])
    }

    /// List pulled repos.
    func pullList() async throws -> String {
        try await captureOutput(args: ["pull", "list"])
    }

    /// Remove a pulled repo.
    func pullRemove(name: String) async throws -> String {
        try await captureOutput(args: ["pull", "remove", name])
    }

    /// Send a test notification.
    func notifyTest(name: String, fail: Bool = false) async throws -> String {
        var args = ["notify", name]
        if fail { args.append("--fail") }
        return try await captureOutput(args: args)
    }

    // MARK: - Private

    private func execute(args: [String], onOutput: @escaping @Sendable (String) -> Void) async throws -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()

        let handle = pipe.fileHandleForReading
        let stream = handle.bytes.lines
        for try await line in stream {
            onOutput(line)
        }

        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    private func captureOutput(args: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            throw CLIError.failed(output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum CLIError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let msg): return msg
        }
    }
}
