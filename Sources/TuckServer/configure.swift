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

    app.logger.notice("🔍 Attempting to parse DATABASE_URL...")
    if let u = URL(string: dbURL) {
        app.logger.notice("✅ DB parsed - host=\(u.host ?? "nil") port=\(u.port?.description ?? "nil") db=\(u.path) scheme=\(u.scheme ?? "nil")")
    } else {
        app.logger.error("❌ DATABASE_URL is not a valid URL")
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
        app.logger.notice("🔧 Using TLS disabled for railway.internal")
        pg.coreConfiguration.tls = .disable
    } else {
        app.logger.notice("🔧 Using TLS required for external database")
        var tls = TLSConfiguration.makeClientConfiguration()
        tls.certificateVerification = .none
        let context = try NIOSSLContext(configuration: tls)
        pg.coreConfiguration.tls = .require(context)
    }

    // Add connection settings
    pg.coreConfiguration.maxConnectionsPerEventLoop = 1
    pg.coreConfiguration.connectionPoolTimeout = .seconds(30)

    app.databases.use(.postgres(configuration: pg), as: .psql, isDefault: true)
    app.logger.notice("📊 Database configuration complete")

    app.migrations.add(CreateUser())
    app.migrations.add(CreateFolder())
    app.migrations.add(CreateBookmark())
    app.logger.notice("📝 Migrations registered")

    // Run migrations with retry logic
    app.logger.notice("🚀 Starting database migration task...")
    Task {
        var attempts = 0
        let maxAttempts = 5
        
        while attempts < maxAttempts {
            attempts += 1
            app.logger.notice("🔄 Migration attempt \(attempts)/\(maxAttempts)...")
            
            do {
                try await app.autoMigrate()
                app.logger.notice("✅ Database migrations completed successfully!")
                return
            } catch {
                app.logger.error("❌ Migration attempt \(attempts) failed: \(error)")
                
                if attempts < maxAttempts {
                    app.logger.notice("⏳ Waiting 5 seconds before retry...")
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                } else {
                    app.logger.error("💥 All migration attempts exhausted. Server running without migrations.")
                }
            }
        }
    }

    // MARK: - JWT
    guard let jwtSecret = Environment.get("JWT_SECRET"), !jwtSecret.isEmpty else {
        fatalError("JWT_SECRET not set in Railway Variables")
    }

    let key = HMACKey(from: Data(jwtSecret.utf8))
    await app.jwt.keys.add(hmac: key, digestAlgorithm: .sha256)
    app.logger.notice("🔐 JWT configured")

    // MARK: - Routes
    try routes(app)
    app.logger.notice("🛣️ Routes registered")
    app.logger.notice("✨ Configuration complete - server ready!")
}
