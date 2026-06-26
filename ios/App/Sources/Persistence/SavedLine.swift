import Foundation
import SwiftData

/// A bookmarked verse. Lives in a SEPARATE writable SwiftData store — never the read-only corpus DB.
/// Stores the VERBATIM Gurmukhi (no saroop markup).
@Model
final class SavedLine {
    @Attribute(.unique) var lineId: Int
    var gurmukhi: String
    var translit: String
    var ang: Int
    var compId: Int
    var savedAt: Date

    init(lineId: Int, gurmukhi: String, translit: String, ang: Int, compId: Int) {
        self.lineId = lineId
        self.gurmukhi = gurmukhi
        self.translit = translit
        self.ang = ang
        self.compId = compId
        self.savedAt = .now
    }
}
