import Vapor
import Fluent
import FluentPostgresDriver
import JWT
import NIOSSL

public func configure(_ app: Application) async throws {

    // MARK: - Server (Railway)
    app.http.server.configuration.hostname = "0.0.0.0"
    if let port = Environment.get("PORT").flatMap(Int.init) {
        app.http.server.configuration.port = port
    } else {
        app.http.server.configuration.port = 8080
    }

    // MARK: - Database
    guard let dbURL = Environment.get("DATABASE_URL") else {
        fatalError("DATABASE_URL not set (Railway should provide this).")
    }
    
    if let u = URL(string: dbURL) {
        app.logger.info("DB host=\(u.host ?? "nil") port=\(u.port?.description ?? "nil") db=\(u.path) scheme=\(u.scheme ?? "nil")")
    } else {
        app.logger.error("DATABASE_URL is not a valid URL")
    }

    let isRailway =
        Environment.get("RAILWAY_ENVIRONMENT") != nil ||
        Environment.get("RAILWAY_PROJECT_ID") != nil ||
        Environment.get("RAILWAY_SERVICE_ID") != nil

    if !isRailway && dbURL.contains("railway.internal") {
        fatalError("""
        DATABASE_URL points to postgres.railway.internal which only resolves on Railway.
        Remove DATABASE_URL from your Xcode Scheme to run locally.
        """)
    }

    var pg = try SQLPostgresConfiguration(url: dbURL)

    if dbURL.contains("railway.internal") {
        pg.coreConfiguration.tls = .disable
    } else {
        var tls = TLSConfiguration.makeClientConfiguration()
        tls.certificateVerification = .none // managed DB cert chain issues are common in containers
        let context = try NIOSSLContext(configuration: tls)
        pg.coreConfiguration.tls = .require(context)

    }

    app.databases.use(.postgres(configuration: pg), as: .psql)
    
    app.migrations.add(CreateUser())
    app.migrations.add(CreateFolder())
    app.migrations.add(CreateBookmark())

    // Don't crash the whole service if DB isn't ready yet; log and keep serving.
    do {
        try await app.autoMigrate()
        app.logger.info("✅ Database migrations completed")
    } catch {
        app.logger.error("❌ Database migration failed: \(error)")
        // Keep running so Railway can route /health and you can see logs.
        // Once DB is reachable, redeploy or trigger migrations again.
    }

    // MARK: - JWT
    guard let jwtSecret = Environment.get("JWT_SECRET"), !jwtSecret.isEmpty else {
        fatalError("JWT_SECRET not set in Railway Variables")
    }

    let key = HMACKey(from: Data(jwtSecret.utf8))
    await app.jwt.keys.add(hmac: key, digestAlgorithm: .sha256)

    // MARK: - Routes
    try routes(app)
}
