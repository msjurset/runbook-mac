import Foundation

struct Runbook: Identifiable, Codable, Hashable {
    var id: String { name }
    var name: String
    var description: String?
    var variables: [VariableDef]?
    var steps: [Step]
    var notify: NotifyConfig?

    /// Resolved file path on disk (not from YAML)
    var filePath: String?

    enum CodingKeys: String, CodingKey {
        case name, description, variables, steps, notify
    }
}

struct VariableDef: Codable, Hashable, Identifiable {
    var id: String { name }
    var name: String
    var `default`: String?
    var required: Bool?
    var prompt: String?
    var secret: Bool?

    enum CodingKeys: String, CodingKey {
        case name, `default`, required, prompt, secret
    }
}

struct Step: Codable, Hashable, Identifiable {
    var id: String { name }
    var name: String
    var type: String?
    var shell: ShellStep?
    var ssh: SSHStep?
    var http: HTTPStep?
    var condition: String?
    var on_error: String?
    var retries: Int?
    var timeout: String?
    var parallel: Bool?
    var confirm: String?
    var capture: String?
}

struct ShellStep: Codable, Hashable {
    var command: String
    var dir: String?
}

struct SSHStep: Codable, Hashable {
    var host: String
    var user: String?
    var port: Int?
    var key_file: String?
    var command: String
    var agent_auth: Bool?
}

struct HTTPStep: Codable, Hashable {
    var method: String?
    var url: String
    var headers: [String: String]?
    var body: String?
}

struct NotifyConfig: Codable, Hashable {
    var on: String?
    var slack: SlackConfig?
    var desktop: Bool?
    var email: EmailConfig?
}

struct SlackConfig: Codable, Hashable {
    var webhook: String
    var channel: String?
}

struct EmailConfig: Codable, Hashable {
    var to: String
    var from: String
    var host: String
    var username: String?
    var password: String?
}
