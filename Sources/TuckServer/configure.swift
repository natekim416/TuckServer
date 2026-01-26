import NIOSSL
import Fluent
import FluentPostgresDriver
import Vapor
import JWT

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    app.databases.use(DatabaseConfigurationFactory.postgres(configuration: .init(
        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
        port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? SQLPostgresConfiguration.ianaPortNumber,
        username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
        password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
        database: Environment.get("DATABASE_NAME") ?? "vapor_database",
        tls: .prefer(try .init(configuration: .clientDefault)))
    ), as: .psql)

    app.migrations.add(CreateUser())
    app.migrations.add(CreateFolder())
    app.migrations.add(CreateBookmark())
    try await app.autoMigrate()

    // JWT 5.0
    let jwtSecret = Environment.get("JWT_SECRET") ?? "dev-insecure-secret"
    let key = HMACKey(from: jwtSecret.data(using: .utf8)!)
    await app.jwt.keys.add(hmac: key, digestAlgorithm: .sha256)


    // register routes
    try routes(app)
}
