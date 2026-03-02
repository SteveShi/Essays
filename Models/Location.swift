import Foundation
import SwiftData

@Model
final class Location: Identifiable {
    var placeholder: String?
    var latitude: Double
    var longitude: Double
    var parentMemo: Memo?

    init(placeholder: String? = nil, latitude: Double, longitude: Double, parentMemo: Memo? = nil) {
        self.placeholder = placeholder
        self.latitude = latitude
        self.longitude = longitude
        self.parentMemo = parentMemo
    }

    var id: String {
        "\(latitude)-\(longitude)"
    }
}
