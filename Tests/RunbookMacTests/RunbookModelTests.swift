import Testing
import Foundation
import Yams
@testable import RunbookMac

@Suite("Runbook Model")
struct RunbookModelTests {
    @Test("Decode minimal runbook YAML")
    func decodeMinimal() throws {
        let yaml = """
        name: test
        steps:
          - name: echo
            type: shell
            shell:
              command: "echo hello"
        """
        let book = try YAMLDecoder().decode(Runbook.self, from: yaml)
        #expect(book.name == "test")
        #expect(book.steps.count == 1)
        #expect(book.steps[0].type == "shell")
        #expect(book.steps[0].shell?.command == "echo hello")
    }

    @Test("Decode full runbook with variables and notify")
    func decodeFull() throws {
        let yaml = """
        name: deploy
        description: Deploy the app
        variables:
          - name: host
            default: "prod-01"
            required: true
          - name: token
            default: "op://Vault/Token"
            secret: true
        notify:
          on: failure
          desktop: true
          slack:
            webhook: "https://hooks.slack.com/test"
        steps:
          - name: Build
            type: shell
            shell:
              command: "make build"
            timeout: 5m
            on_error: abort
          - name: Deploy
            type: ssh
            ssh:
              host: "{{.host}}"
              user: deploy
              agent_auth: true
              command: "sudo restart app"
            capture: deploy_output
        """
        let book = try YAMLDecoder().decode(Runbook.self, from: yaml)
        #expect(book.name == "deploy")
        #expect(book.description == "Deploy the app")
        #expect(book.variables?.count == 2)
        #expect(book.variables?[0].required == true)
        #expect(book.variables?[1].secret == true)
        #expect(book.notify?.on == "failure")
        #expect(book.notify?.desktop == true)
        #expect(book.notify?.slack?.webhook == "https://hooks.slack.com/test")
        #expect(book.steps.count == 2)
        #expect(book.steps[0].timeout == "5m")
        #expect(book.steps[0].on_error == "abort")
        #expect(book.steps[1].ssh?.agent_auth == true)
        #expect(book.steps[1].capture == "deploy_output")
    }

    @Test("Decode HTTP step")
    func decodeHTTPStep() throws {
        let yaml = """
        name: healthcheck
        steps:
          - name: Check API
            type: http
            http:
              method: GET
              url: "https://api.example.com/health"
              headers:
                Authorization: "Bearer token123"
        """
        let book = try YAMLDecoder().decode(Runbook.self, from: yaml)
        let step = book.steps[0]
        #expect(step.http?.method == "GET")
        #expect(step.http?.url == "https://api.example.com/health")
        #expect(step.http?.headers?["Authorization"] == "Bearer token123")
    }

    @Test("Decode confirm-only step")
    func decodeConfirmStep() throws {
        let yaml = """
        name: test
        steps:
          - name: Confirm
            confirm: "Are you sure?"
        """
        let book = try YAMLDecoder().decode(Runbook.self, from: yaml)
        #expect(book.steps[0].type == nil)
        #expect(book.steps[0].confirm == "Are you sure?")
    }

    @Test("Runbook identity uses name")
    func identity() throws {
        let yaml = """
        name: my-book
        steps:
          - name: s1
            type: shell
            shell:
              command: "echo"
        """
        let book = try YAMLDecoder().decode(Runbook.self, from: yaml)
        #expect(book.id == "my-book")
    }

    @Test("Encode and decode roundtrip")
    func roundtrip() throws {
        let book = Runbook(
            name: "test",
            description: "A test",
            variables: [VariableDef(name: "host", default: "localhost")],
            steps: [Step(name: "echo", type: "shell", shell: ShellStep(command: "echo hi"))]
        )
        let yaml = try YAMLEncoder().encode(book)
        let decoded = try YAMLDecoder().decode(Runbook.self, from: yaml)
        #expect(decoded.name == book.name)
        #expect(decoded.steps.count == 1)
    }
}

@Suite("History Record")
struct HistoryRecordTests {
    @Test("Decode history JSON")
    func decodeJSON() throws {
        let json = """
        {
          "runbook_name": "deploy",
          "started_at": "2026-03-16T12:00:00Z",
          "duration": "2.5s",
          "success": true,
          "step_count": 2,
          "steps": [
            {"name": "build", "status": "success", "duration": "1s"},
            {"name": "deploy", "status": "success", "duration": "1.5s"}
          ]
        }
        """
        let record = try JSONDecoder().decode(HistoryRecord.self, from: json.data(using: .utf8)!)
        #expect(record.runbook_name == "deploy")
        #expect(record.success == true)
        #expect(record.step_count == 2)
        #expect(record.steps.count == 2)
        #expect(record.steps[0].name == "build")
    }

    @Test("Decode history with error")
    func decodeWithError() throws {
        let json = """
        {
          "runbook_name": "deploy",
          "started_at": "2026-03-16T12:00:00Z",
          "duration": "1s",
          "success": false,
          "step_count": 1,
          "steps": [
            {"name": "build", "status": "failed", "duration": "1s", "error": "exit code 1"}
          ]
        }
        """
        let record = try JSONDecoder().decode(HistoryRecord.self, from: json.data(using: .utf8)!)
        #expect(record.success == false)
        #expect(record.steps[0].error == "exit code 1")
    }

    @Test("History record identity")
    func identity() throws {
        let json = """
        {"runbook_name": "test", "started_at": "2026-03-16T12:00:00Z", "duration": "0s", "success": true, "step_count": 0, "steps": []}
        """
        let record = try JSONDecoder().decode(HistoryRecord.self, from: json.data(using: .utf8)!)
        #expect(record.id == "test_2026-03-16T12:00:00Z")
    }
}
