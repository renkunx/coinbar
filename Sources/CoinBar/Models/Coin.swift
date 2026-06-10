import Foundation

struct Coin: Identifiable, Codable, Equatable {
    var id: String { instId }

    let instId: String
    let symbol: String
}
