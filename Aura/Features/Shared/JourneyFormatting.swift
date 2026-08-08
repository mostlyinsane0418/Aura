import AuraKit
import Foundation

/// Journey dates read as a human would say them: "4–7 August", "31 Dec – 2 Jan 2025",
/// "6 August 2024". Never "04/08/2026 – 07/08/2026".
enum JourneyFormatting {

    static func dateRange(from start: Date, to end: Date, calendar: Calendar = .current) -> String {
        let sameDay = calendar.isDate(start, inSameDayAs: end)
        let sameYear = calendar.component(.year, from: start) == calendar.component(.year, from: end)
        let sameMonth = sameYear
            && calendar.component(.month, from: start) == calendar.component(.month, from: end)
        let isCurrentYear = calendar.component(.year, from: start)
            == calendar.component(.year, from: Date())

        if sameDay {
            return start.formatted(
                .dateTime.day().month(.wide).year(isCurrentYear ? .omitted : .defaultDigits)
            )
        }

        if sameMonth {
            let startDay = start.formatted(.dateTime.day())
            let endPart = end.formatted(
                .dateTime.day().month(.wide).year(isCurrentYear ? .omitted : .defaultDigits)
            )
            return "\(startDay)–\(endPart)"
        }

        let startPart = start.formatted(.dateTime.day().month(.abbreviated))
        let endPart = end.formatted(
            .dateTime.day().month(.abbreviated).year(isCurrentYear ? .omitted : .defaultDigits)
        )
        return "\(startPart) – \(endPart)"
    }

    /// "3 days · 214 photos" — the two facts worth putting under a title.
    static func summary(for journey: Journey) -> String {
        let days = journey.dayCount
        let dayPart = days == 1 ? "1 day" : "\(days) days"
        let count = journey.memoryIDs.count
        let photoPart = count == 1 ? "1 photo" : "\(count) photos"
        return "\(dayPart) · \(photoPart)"
    }

    static func chapterTitle(for chapter: Chapter, in journey: Journey, calendar: Calendar = .current) -> String {
        let day = (calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: journey.startDate),
            to: calendar.startOfDay(for: chapter.startDate)
        ).day ?? 0) + 1

        if let name = chapter.place?.name ?? chapter.place?.locality {
            return "Day \(day) · \(name)"
        }
        return "Day \(day)"
    }
}
