import Foundation

/// Compute the next fire time for a 5-field cron expression.
/// Supports `*`, `N`, `N-M`, `N,M,O`, and `*/N` / `N-M/S` steps in each field.
/// Follows Vixie-cron day-of-month/day-of-week semantics: if both are
/// restricted, a day matches when EITHER restriction is satisfied.
enum CronNextRun {
    static func next(for expression: String, after start: Date = Date()) -> Date? {
        let parts = expression.trimmingCharacters(in: .whitespaces)
            .split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard parts.count == 5 else { return nil }

        guard let mins   = parseField(parts[0], min: 0, max: 59),
              let hours  = parseField(parts[1], min: 0, max: 23),
              let doms   = parseField(parts[2], min: 1, max: 31),
              let months = parseField(parts[3], min: 1, max: 12),
              let dows   = parseField(parts[4], min: 0, max: 7) else { return nil }
        // Cron accepts 7 as Sunday too; normalize.
        var dowsNormalized = dows
        if dowsNormalized.contains(7) {
            dowsNormalized.remove(7)
            dowsNormalized.insert(0)
        }

        let calendar = Calendar.current
        // Bump to the next whole minute.
        var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: start)
        comps.second = 0
        guard var candidate = calendar.date(from: comps) else { return nil }
        candidate = calendar.date(byAdding: .minute, value: 1, to: candidate) ?? candidate

        guard let horizon = calendar.date(byAdding: .day, value: 366, to: start) else { return nil }

        let domField = parts[2], dowField = parts[4]
        while candidate <= horizon {
            let c = calendar.dateComponents([.minute, .hour, .day, .month, .weekday], from: candidate)
            let minute  = c.minute  ?? -1
            let hour    = c.hour    ?? -1
            let day     = c.day     ?? -1
            let month   = c.month   ?? -1
            let weekday = ((c.weekday ?? 1) - 1) // Calendar: 1=Sun ... 7=Sat → cron: 0=Sun ... 6=Sat

            if mins.contains(minute) && hours.contains(hour) && months.contains(month)
                && dayMatches(dom: day, dow: weekday, domField: domField, dowField: dowField,
                              domSet: doms, dowSet: dowsNormalized) {
                return candidate
            }
            candidate = calendar.date(byAdding: .minute, value: 1, to: candidate) ?? candidate
        }
        return nil
    }

    private static func parseField(_ field: String, min lo: Int, max hi: Int) -> Set<Int>? {
        let tokens = field.split(separator: ",", omittingEmptySubsequences: true).map(String.init)
        guard !tokens.isEmpty else { return nil }

        var result: Set<Int> = []
        for tok in tokens {
            var step = 1
            var base = tok
            if let slash = tok.firstIndex(of: "/") {
                guard let s = Int(tok[tok.index(after: slash)...]), s > 0 else { return nil }
                step = s
                base = String(tok[..<slash])
            }

            if base == "*" || base.isEmpty {
                for v in stride(from: lo, through: hi, by: step) { result.insert(v) }
            } else if let dash = base.firstIndex(of: "-") {
                let a = String(base[..<dash])
                let b = String(base[base.index(after: dash)...])
                guard let aInt = Int(a), let bInt = Int(b),
                      aInt >= lo, bInt <= hi, aInt <= bInt else { return nil }
                for v in stride(from: aInt, through: bInt, by: step) { result.insert(v) }
            } else {
                guard let v = Int(base), v >= lo, v <= hi else { return nil }
                // A bare value with a step (e.g., "5/10") means start at 5, step 10 up to max.
                if step != 1 {
                    for x in stride(from: v, through: hi, by: step) { result.insert(x) }
                } else {
                    result.insert(v)
                }
            }
        }
        return result
    }

    /// Vixie-cron OR semantics when both dom and dow are restricted.
    private static func dayMatches(dom: Int, dow: Int,
                                   domField: String, dowField: String,
                                   domSet: Set<Int>, dowSet: Set<Int>) -> Bool {
        let domWild = (domField == "*")
        let dowWild = (dowField == "*")
        if domWild && dowWild { return true }
        if domWild  { return dowSet.contains(dow) }
        if dowWild  { return domSet.contains(dom) }
        return domSet.contains(dom) || dowSet.contains(dow)
    }
}

/// Human-readable relative time for cron displays.
enum CronRelativeTime {
    /// Short-form relative duration: "24m", "3h", "5d 2h", "in 3d".
    static func until(_ date: Date, from now: Date = Date()) -> String {
        let seconds = Int(date.timeIntervalSince(now))
        if seconds <= 0 { return "now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 {
            let m = minutes % 60
            return m > 0 ? "\(hours)h \(m)m" : "\(hours)h"
        }
        let days = hours / 24
        let h = hours % 24
        return h > 0 ? "\(days)d \(h)h" : "\(days)d"
    }

    /// Short-form absolute when nearby, date when distant.
    static func friendly(_ date: Date, from now: Date = Date()) -> String {
        let cal = Calendar.current
        let df = DateFormatter()
        df.locale = Locale.current
        if cal.isDateInToday(date)      { df.dateFormat = "'Today at' h:mm a";     return df.string(from: date) }
        if cal.isDateInTomorrow(date)   { df.dateFormat = "'Tomorrow at' h:mm a";  return df.string(from: date) }
        if cal.isDateInYesterday(date)  { df.dateFormat = "'Yesterday at' h:mm a"; return df.string(from: date) }
        let daysOut = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: date)).day ?? 0
        if (1...6).contains(daysOut)    { df.dateFormat = "EEEE 'at' h:mm a";      return df.string(from: date) }
        if cal.isDate(date, equalTo: now, toGranularity: .year) {
            df.dateFormat = "MMM d 'at' h:mm a"
        } else {
            df.dateFormat = "MMM d, yyyy 'at' h:mm a"
        }
        return df.string(from: date)
    }
}
