import Fluent

struct CreateBookmark: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("bookmarks")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("folder_id", .uuid, .references("folders", "id", onDelete: .setNull))
            .field("url", .string, .required)
            .field("title", .string)
            .field("notes", .string)
            .field("created_at", .datetime)
            .create()
    }
    
    func revert(on database: any Database) async throws {
        try await database.schema("bookmarks").delete()
    }
}
