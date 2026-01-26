import Vapor
import Fluent

struct FolderController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let folders = routes.grouped("folders")
        
        let protected = folders.grouped(UserJWTAuthenticator())
            .grouped(User.guardMiddleware())
        
        protected.get(use: index)
        protected.post(use: create)
        protected.get(":folderID", "bookmarks", use: getBookmarks)
    }
    
    func index(req: Request) async throws -> [Folder] {
        let user = try req.auth.require(User.self)
        return try await Folder.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .sort(\.$createdAt, .descending)
            .all()
    }
    
    func create(req: Request) async throws -> Folder {
        let user = try req.auth.require(User.self)
        let data = try req.content.decode(CreateFolderRequest.self)
        
        let folder = Folder(userId: user.id!, name: data.name, color: data.color)
        try await folder.save(on: req.db)
        
        return folder
    }
    
    func getBookmarks(req: Request) async throws -> [Bookmark] {
        let user = try req.auth.require(User.self)
        guard let folderID = req.parameters.get("folderID", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        return try await Bookmark.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .filter(\.$folder.$id == folderID)
            .all()
    }
}

struct CreateFolderRequest: Content {
    let name: String
    let color: String?
}
