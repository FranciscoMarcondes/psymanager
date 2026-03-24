import Foundation
import SwiftData

@Model
final class PromoterContact {
    var name: String
    var city: String
    var state: String
    var instagramHandle: String
    var phone: String
    var email: String
    var notes: String

    init(
        name: String,
        city: String,
        state: String,
        instagramHandle: String,
        phone: String,
        email: String,
        notes: String
    ) {
        self.name = name
        self.city = city
        self.state = state
        self.instagramHandle = instagramHandle
        self.phone = phone
        self.email = email
        self.notes = notes
    }
}