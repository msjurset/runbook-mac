import Foundation

struct HistoryRecord: Identifiable, Codable {
    var id: String { "\(runbook_name)_\(started_at)" }
    var runbook_name: String
    var file_path: String?
    var started_at: String
    var duration: String
    var success: Bool
    var step_count: Int
    var steps: [StepRecord]

    var startedDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: started_at)
            ?? ISO8601DateFormatter().date(from: started_at)
    }
}

struct StepRecord: Identifiable, Codable {
    var id: String { name }
    var name: String
    var type: String?
    var status: String
    var duration: String
    var error: String?
}
