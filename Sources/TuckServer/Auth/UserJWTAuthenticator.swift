import Vapor
import Fluent
import JWTKit

struct UserJWTAuthenticator: AsyncJWTAuthenticator {
    typealias Payload = UserJWTPayload

    func authenticate(jwt: UserJWTPayload, for req: Request) -> EventLoopFuture<Void> {
        guard let userID = UUID(uuidString: jwt.subject.value) else {
            return req.eventLoop.makeSucceededFuture(())
        }

        return User.find(userID, on: req.db).map { user in
            if let user {
                req.auth.login(user)
            }
        }
    }
}
