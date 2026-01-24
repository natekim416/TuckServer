import Vapor
import JWT

struct UserJWTPayload: JWTPayload, Equatable {
    // Claims
    var exp: ExpirationClaim
    var sub: SubjectClaim  // This is the userId
    
    // Convenience
    var userId: UUID {
        UUID(uuidString: sub.value)!
    }
    
    // Initialize with userId
    init(userId: UUID, expiration: Date) {
        self.sub = SubjectClaim(value: userId.uuidString)
        self.exp = ExpirationClaim(value: expiration)
    }
    
    // JWT 5.0 uses 'some JWTAlgorithm' instead of JWTSigner
    func verify(using algorithm: some JWTAlgorithm) throws {
        try exp.verifyNotExpired()
    }
}
