import Foundation

struct MonthlyTokenUsage: Identifiable, Equatable, Sendable {
    var id: Date { month }
    let month: Date
    let usage: LocalTokenUsage?
}
