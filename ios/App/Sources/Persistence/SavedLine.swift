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

/// Versioned schema for the bookmarks store. Adopted BEFORE the first TestFlight build so a
/// future change to `SavedLine` can ship as a real migration stage instead of landing on the
/// destroy-and-recreate rung. V1 is byte-identical to the un-versioned model that dev builds
/// used, so existing stores open without migrating.
enum SavedLineSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [SavedLine.self] }
}

enum SavedLineMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SavedLineSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
