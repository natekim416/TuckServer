import Vapor
import Fluent
import JWT

func routes(_ app: Application) throws {
    // Public routes
    try app.register(collection: AuthController())
    
    // Protected routes (require JWT)
    let protected = app.grouped(UserJWTAuthenticator())
        .grouped(User.guardMiddleware())
    
    try protected.register(collection: SmartSortController())
}
