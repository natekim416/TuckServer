import Vapor
import Fluent
import FluentPostgresDriver
import JWT

public func configure(_ app: Application) async throws {

    // MARK: - Server (Railway)
    app.http.server.configuration.hostname = "0.0.0.0"
    if let port = Environment.get("PORT").flatMap(Int.init) {
        app.http.server.configuration.port = port
    }

    // MARK: - Database
    guard let dbURL = Environment.get("DATABASE_URL") else {
        fatalError("DATABASE_URL not set (Railway should provide this on deploy).")
    }

    // If you're running locally but DATABASE_URL is the Railway internal host,
    // it will never resolve. Give a helpful error instead of mystery DNS crashes.
    let isRailway =
        Environment.get("RAILWAY_ENVIRONMENT") != nil ||
        Environment.get("RAILWAY_PROJECT_ID") != nil ||
        Environment.get("RAILWAY_SERVICE_ID") != nil

    if !isRailway && dbURL.contains("railway.internal") {
        fatalError("""
        DATABASE_URL points to postgres.railway.internal which only resolves on Railway.
        Remove DATABASE_URL (and DB env vars) from your Xcode Scheme to run locally.
        """)
    }

    var pg = try SQLPostgresConfiguration(url: dbURL)

    // Internal Railway network: no TLS needed
    if dbURL.contains("railway.internal") {
        pg.coreConfiguration.tls = .disable
    }

    app.databases.use(.postgres(configuration: pg), as: .psql)

    // MARK: - Migrations
    app.migrations.add(CreateUser())
    app.migrations.add(CreateFolder())
    app.migrations.add(CreateBookmark())
    try await app.autoMigrate()

    // MARK: - JWT
    guard let jwtSecret = Environment.get("JWT_SECRET") else {
        fatalError("JWT_SECRET not set in Railway Variables")
    }
    let key = HMACKey(from: Data(jwtSecret.utf8))
    await app.jwt.keys.add(hmac: key, digestAlgorithm: .sha256)

    // MARK: - Routes
    try routes(app)
}
