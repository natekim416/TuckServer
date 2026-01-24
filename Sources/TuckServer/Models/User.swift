import Vapor
import Fluent

final class User: Model, Authenticatable, @unchecked Sendable {
    static let schema = "users"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "email")
    var email: String

    @Field(key: "passwordHash")
    var passwordHash: String

    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    init() {}

    init(id: UUID? = nil, email: String, passwordHash: String) {
        self.id = id
        self.email = email
        self.passwordHash = passwordHash
    }
}

struct PublicUser: Content {
    let id: UUID?
    let email: String
    let createdAt: Date?
}

extension User {
    var asPublic: PublicUser {
        .init(id: id, email: email, createdAt: createdAt)
    }
}
