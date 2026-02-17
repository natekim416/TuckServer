import Vapor
import Fluent

struct FolderController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let folders = routes.grouped("folders")
        
        folders.get(use: index)
        folders.post(use: create)
        folders.get(":folderID", "bookmarks", use: getBookmarks)
        folders.delete(":folderID", use: delete)
        folders.patch(":folderID", use: update)
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
    
    func delete(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        guard let folderID = req.parameters.get("folderID", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        guard let folder = try await Folder.query(on: req.db)
            .filter(\.$id == folderID)
            .filter(\.$user.$id == user.id!)
            .first() else {
            throw Abort(.notFound, reason: "Folder not found")
        }
        
        // Delete all bookmarks in this folder first
        try await Bookmark.query(on: req.db)
            .filter(\.$folder.$id == folderID)
            .filter(\.$user.$id == user.id!)
            .delete()
        
        try await folder.delete(on: req.db)
        return .ok
    }
    
    func update(req: Request) async throws -> Folder {
        let user = try req.auth.require(User.self)
        guard let folderID = req.parameters.get("folderID", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        guard let folder = try await Folder.query(on: req.db)
            .filter(\.$id == folderID)
            .filter(\.$user.$id == user.id!)
            .first() else {
            throw Abort(.notFound, reason: "Folder not found")
        }
        
        let data = try req.content.decode(UpdateFolderRequest.self)
        
        if let name = data.name {
            folder.name = name
        }
        if let color = data.color {
            folder.color = color
        }
        
        try await folder.save(on: req.db)
        return folder
    }
}

struct CreateFolderRequest: Content {
    let name: String
    let color: String?
}

struct UpdateFolderRequest: Content {
    let name: String?
    let color: String?
    let isPublic: Bool?
}
