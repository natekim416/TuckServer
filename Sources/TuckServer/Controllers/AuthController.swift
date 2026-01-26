import Vapor
import Fluent
import JWT

struct RegisterRequest: Content { let email: String; let password: String }
struct LoginRequest: Content { let email: String; let password: String }

struct AuthResponse: Content {
    let token: String
    let user: PublicUser
}

struct AuthController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let auth = routes.grouped("auth")
        auth.post("register", use: register)
        auth.post("login", use: login)
    }

    func register(req: Request) async throws -> AuthResponse {
        let data = try req.content.decode(RegisterRequest.self)
        let email = data.email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        guard email.contains("@"), data.password.count >= 8 else {
            throw Abort(.badRequest, reason: "Invalid email or password must be ≥ 8 chars.")
        }

        let existing = try await User.query(on: req.db).filter(\.$email == email).first()
        guard existing == nil else { throw Abort(.conflict, reason: "Email already in use.") }

        let hash = try Bcrypt.hash(data.password)
        let user = User(email: email, passwordHash: hash)
        try await user.save(on: req.db)

        return try await issueToken(for: user, req: req)
    }

    func login(req: Request) async throws -> AuthResponse {
        let data = try req.content.decode(LoginRequest.self)
        let email = data.email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        guard let user = try await User.query(on: req.db).filter(\.$email == email).first() else {
            throw Abort(.unauthorized, reason: "Invalid credentials.")
        }
        guard try Bcrypt.verify(data.password, created: user.passwordHash) else {
            throw Abort(.unauthorized, reason: "Invalid credentials.")
        }

        return try await issueToken(for: user, req: req)
    }
    
    private func issueToken(for user: User, req: Request) async throws -> AuthResponse {
        let userId = try user.requireID()
        let expiration = Date().addingTimeInterval(60 * 60 * 24 * 7)
        
        let payload = UserJWTPayload(userId: userId, expiration: expiration)
        let token = try await req.jwt.sign(payload)
        
        return AuthResponse(token: token, user: user.asPublic)
    }
}
