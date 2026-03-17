import Testing
import Yams
@testable import RunbookMac

@Suite("Runbook Templates")
struct RunbookTemplateTests {
    @Test("All templates exist")
    func templatesExist() {
        #expect(RunbookTemplate.templates.count >= 4)
    }

    @Test("All templates have valid YAML")
    func templatesValidYAML() throws {
        for template in RunbookTemplate.templates {
            let decoded = try YAMLDecoder().decode(Runbook.self, from: template.content)
            #expect(!decoded.name.isEmpty, "Template \(template.id) has empty name")
            #expect(!decoded.steps.isEmpty, "Template \(template.id) has no steps")
        }
    }

    @Test("Templates have unique IDs")
    func uniqueIDs() {
        let ids = RunbookTemplate.templates.map(\.id)
        let uniqueIDs = Set(ids)
        #expect(ids.count == uniqueIDs.count)
    }

    @Test("Blank template is first")
    func blankFirst() {
        #expect(RunbookTemplate.templates[0].id == "blank")
    }

    @Test("Templates have descriptions")
    func descriptions() {
        for template in RunbookTemplate.templates {
            #expect(!template.description.isEmpty, "Template \(template.id) has no description")
        }
    }
}
