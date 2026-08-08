import Foundation
@testable import AuraKit

enum Fixtures {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// 2026-01-01T00:00:00Z, a convenient epoch for readable relative offsets.
    static let epoch = Date(timeIntervalSince1970: 1_767_225_600)

    static func date(day: Double, hour: Double = 12, minute: Double = 0) -> Date {
        epoch.addingTimeInterval(day * 86_400 + hour * 3_600 + minute * 60)
    }

    static let bristol = Coordinate(latitude: 51.4545, longitude: -2.5879)
    static let cliftonObservatory = Coordinate(latitude: 51.4550, longitude: -2.6280)
    static let bath = Coordinate(latitude: 51.3811, longitude: -2.3590)
    static let london = Coordinate(latitude: 51.5072, longitude: -0.1276)
    static let lisbon = Coordinate(latitude: 38.7223, longitude: -9.1393)
    /// ~24km from Lisbon: same trip, different chapter.
    static let sintra = Coordinate(latitude: 38.7979, longitude: -9.3907)
    static let tokyo = Coordinate(latitude: 35.6762, longitude: 139.6503)

    /// A burst of photos at one place, spread evenly across a window of hours.
    static func burst(
        _ prefix: String,
        at coordinate: Coordinate?,
        day: Double,
        startHour: Double = 10,
        spanHours: Double = 4,
        count: Int = 8
    ) -> [MemorySeed] {
        (0..<count).map { index in
            let fraction = count == 1 ? 0 : Double(index) / Double(count - 1)
            return MemorySeed(
                id: "\(prefix)-\(index)",
                createdAt: date(day: day, hour: startHour + fraction * spanHours),
                coordinate: coordinate
            )
        }
    }

    /// Night-time photos at home, which is what home-base inference keys off.
    static func nightsAtHome(
        _ coordinate: Coordinate,
        nights: Int,
        perNight: Int = 3,
        startingDay: Double = -400
    ) -> [MemorySeed] {
        var seeds: [MemorySeed] = []
        for night in 0..<nights {
            for index in 0..<perNight {
                seeds.append(MemorySeed(
                    id: "home-\(night)-\(index)",
                    createdAt: date(day: startingDay + Double(night), hour: 22 + Double(index) * 0.5),
                    coordinate: coordinate
                ))
            }
        }
        return seeds
    }
}
