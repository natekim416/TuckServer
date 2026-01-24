import Fluent

struct CreateUser: Migration {
    func prepare(on db: any Database) -> EventLoopFuture<Void> {
        db.schema("users")
            .id()
            .field("email", .string, .required)
            .unique(on: "email")
            .field("passwordHash", .string, .required)
            .field("createdAt", .datetime)
            .create()
    }

    func revert(on db: any Database) -> EventLoopFuture<Void> {
        db.schema("users").delete()
    }
}
