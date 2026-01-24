import Vapor
import Fluent
import JWT

struct UserJWTAuthenticator: JWTAuthenticator {
    typealias Payload = UserJWTPayload

    func authenticate(jwt: UserJWTPayload, for req: Request) async throws {
        guard let user = try await User.find(jwt.userId, on: req.db) else {
            return
        }
        req.auth.login(user)
    }
}
