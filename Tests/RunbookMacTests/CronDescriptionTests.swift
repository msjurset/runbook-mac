import Testing
@testable import RunbookMac

@Suite("CronDescription")
struct CronDescriptionTests {
    @Test func everyMinute() {
        #expect(CronDescription.describe("* * * * *") == "Every minute, every day")
    }

    @Test func everyFiveMinutes() {
        #expect(CronDescription.describe("*/5 * * * *") == "Every 5 minutes, every day")
    }

    @Test func dailyAtNineAM() {
        #expect(CronDescription.describe("0 9 * * *") == "At 9:00 AM, every day")
    }

    @Test func dailyAtMidnight() {
        #expect(CronDescription.describe("0 0 * * *") == "At 12:00 AM, every day")
    }

    @Test func weeklySunday() {
        #expect(CronDescription.describe("0 3 * * 0") == "At 3:00 AM, on Sundays")
    }

    @Test func weekdayRange() {
        #expect(CronDescription.describe("30 8 * * 1-5") == "At 8:30 AM, Monday through Friday")
    }

    @Test func specificDayOfMonth() {
        #expect(CronDescription.describe("0 12 15 * *") == "At 12:00 PM, on the 15th")
    }

    @Test func monthlyFirstDay() {
        #expect(CronDescription.describe("0 6 1 * *") == "At 6:00 AM, on the 1st")
    }

    @Test func specificMonth() {
        #expect(CronDescription.describe("0 9 * 3 *") == "At 9:00 AM, in March")
    }

    @Test func everyHourSteps() {
        #expect(CronDescription.describe("0 */2 * * *") == "At minute 0, every 2 hours, every day")
    }

    @Test func multipleDays() {
        #expect(CronDescription.describe("0 9 * * 1,3,5") == "At 9:00 AM, on Monday and Wednesday and Friday")
    }

    @Test func invalidExpression() {
        #expect(CronDescription.describe("not a cron") == "")
    }

    @Test func tooFewFields() {
        #expect(CronDescription.describe("* * *") == "")
    }

    // MARK: - Ordinal

    @Test func ordinals() {
        #expect(CronDescription.ordinal("1") == "1st")
        #expect(CronDescription.ordinal("2") == "2nd")
        #expect(CronDescription.ordinal("3") == "3rd")
        #expect(CronDescription.ordinal("4") == "4th")
        #expect(CronDescription.ordinal("11") == "11th")
        #expect(CronDescription.ordinal("12") == "12th")
        #expect(CronDescription.ordinal("13") == "13th")
        #expect(CronDescription.ordinal("21") == "21st")
        #expect(CronDescription.ordinal("22") == "22nd")
    }
}
