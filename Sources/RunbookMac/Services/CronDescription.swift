import Foundation

/// Converts a 5-field cron expression into a human-readable English description.
enum CronDescription {
    static func describe(_ expr: String) -> String {
        let parts = expr.trimmingCharacters(in: .whitespaces).split(separator: " ").map(String.init)
        guard parts.count == 5 else { return "" }

        let minute = parts[0]
        let hour = parts[1]
        let dom = parts[2]
        let month = parts[3]
        let dow = parts[4]

        let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let monthNames = ["", "January", "February", "March", "April", "May", "June",
                          "July", "August", "September", "October", "November", "December"]

        // Build the frequency/time part
        var time = ""
        if minute == "*" && hour == "*" {
            time = "Every minute"
        } else if minute.hasPrefix("*/") && hour == "*" {
            time = "Every \(minute.dropFirst(2)) minutes"
        } else if minute.hasPrefix("*/") {
            let h = Int(hour) ?? 0
            let ampm = h >= 12 ? "PM" : "AM"
            let h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h)
            time = "Every \(minute.dropFirst(2)) minutes past \(h12) \(ampm)"
        } else if hour.hasPrefix("*/") {
            time = "At minute \(minute), every \(hour.dropFirst(2)) hours"
        } else if hour == "*" {
            time = "At minute \(minute) of every hour"
        } else if hour.contains(",") {
            let hours = hour.split(separator: ",").compactMap { Int($0) }.map { h in
                let ampm = h >= 12 ? "PM" : "AM"
                let h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h)
                return "\(h12) \(ampm)"
            }
            time = "At minute \(minute) past \(hours.joined(separator: " and "))"
        } else {
            let h = Int(hour) ?? 0
            let m = Int(minute) ?? 0
            let ampm = h >= 12 ? "PM" : "AM"
            let h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h)
            time = String(format: "At %d:%02d %@", h12, m, ampm)
        }

        // Build the "when" part
        let allDaysWild = dom == "*" && dow == "*"
        let monthWild = month == "*"

        var when = ""

        if allDaysWild && monthWild {
            when = "every day"
        } else {
            // Describe day-of-week
            var dowDesc = ""
            if dow != "*" {
                if dow.contains("/") {
                    let stepParts = dow.split(separator: "/")
                    let start = String(stepParts[0])
                    let step = String(stepParts.count > 1 ? stepParts[1] : "")
                    if start == "*" {
                        dowDesc = "every \(step) days of the week"
                    } else if let d = Int(start), d >= 0, d <= 6 {
                        dowDesc = "every \(step) days starting on \(dayNames[d])"
                    }
                } else if let d = Int(dow), d >= 0, d <= 6 {
                    dowDesc = "on \(dayNames[d])s"
                } else if dow.contains(",") {
                    let days = dow.split(separator: ",").compactMap { Int($0) }.compactMap { d in
                        d >= 0 && d <= 6 ? dayNames[d] : nil
                    }
                    dowDesc = "on \(days.joined(separator: " and "))"
                } else if dow.contains("-") {
                    let range = dow.split(separator: "-").compactMap { Int($0) }
                    if range.count == 2, range[0] >= 0, range[1] <= 6 {
                        dowDesc = "\(dayNames[range[0]]) through \(dayNames[range[1]])"
                    }
                }
            }

            // Describe day-of-month
            var domDesc = ""
            if dom != "*" {
                if dom.contains("/") {
                    let stepParts = dom.split(separator: "/")
                    let start = String(stepParts[0])
                    let step = String(stepParts.count > 1 ? stepParts[1] : "")
                    if start == "*" {
                        domDesc = "every \(step) days"
                    } else {
                        domDesc = "every \(step) days starting on the \(ordinal(start))"
                    }
                } else if dom.contains(",") {
                    let days = dom.split(separator: ",").map { ordinal(String($0)) }
                    domDesc = "on the \(days.joined(separator: ", "))"
                } else if dom.contains("-") {
                    let range = dom.split(separator: "-")
                    if range.count == 2 {
                        domDesc = "on the \(ordinal(String(range[0]))) through the \(ordinal(String(range[1])))"
                    } else {
                        domDesc = "on days \(dom)"
                    }
                } else {
                    domDesc = "on the \(ordinal(dom))"
                }
            }

            if !domDesc.isEmpty && !dowDesc.isEmpty {
                when = "\(domDesc) and \(dowDesc)"
            } else if !dowDesc.isEmpty {
                when = dowDesc
            } else if !domDesc.isEmpty {
                when = domDesc
            }

            // Month
            if !monthWild {
                if let m = Int(month), m >= 1, m <= 12 {
                    let monthPart = "in \(monthNames[m])"
                    when = when.isEmpty ? monthPart : "\(when) \(monthPart)"
                }
            }
        }

        if when.isEmpty {
            return time
        }

        if time.hasPrefix("Every") {
            return "\(time), \(when)"
        }
        return "\(time), \(when)"
    }

    static func ordinal(_ s: String) -> String {
        guard let n = Int(s) else { return s }
        let suffix: String
        if (11...13).contains(n % 100) {
            suffix = "th"
        } else {
            switch n % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }
}
