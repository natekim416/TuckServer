import Fluent

struct CreateFolder: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("folders")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("name", .string, .required)
            .field("color", .string)
            .field("created_at", .datetime)
            .create()
    }
    
    func revert(on database: any Database) async throws {
        try await database.schema("folders").delete()
    }
}
