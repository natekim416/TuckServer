import JWTKit
import JWT

struct UserJWTPayload: JWTPayload {
    var subject: SubjectClaim
    var expiration: ExpirationClaim
    var issuedAt: IssuedAtClaim

    func verify(using signer: JWTSigner) throws {
        try expiration.verifyNotExpired()
    }
}
