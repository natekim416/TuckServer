import Vapor

func routes(_ app: Application) throws {
    try app.register(collection: AuthController())

    let protected = app.grouped(
        UserJWTPayload.authenticator(),
        UserJWTAuthenticator(),
        User.guardMiddleware()
    )

    protected.get("me") { req async throws -> PublicUser in
        let user = try req.auth.require(User.self)
        return user.asPublic
    }

    try protected.group("api") { api in
        try api.register(collection: SmartSortController())
    }
}
