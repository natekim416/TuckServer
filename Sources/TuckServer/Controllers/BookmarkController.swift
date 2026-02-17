import Vapor
import Fluent

struct BookmarkController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let bookmarks = routes.grouped("bookmarks")
        
        bookmarks.post("smart-save", use: analyzeAndSave)
        bookmarks.get(use: index)
        bookmarks.delete(":bookmarkID", use: delete)
    }
    
    func analyzeAndSave(req: Request) async throws -> SavedBookmarkResponse {
        let user = try req.auth.require(User.self)
        let data = try req.content.decode(AnalyzeAndSaveRequest.self)
        
        // 1. Get existing folder names for this user
        let existingFolders = try await Folder.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .all()
        let folderNames = existingFolders.map { $0.name }
        let folderContext = folderNames.isEmpty ? "" : "Existing folders: \(folderNames.joined(separator: ", "))"
        
        // 2. Analyze with AI, including existing folders as context
        let text = [data.url, data.title, data.notes].compactMap { $0 }.joined(separator: " ")
        let smartSortController = SmartSortController()
        let aiRequest = SmartSortRequest(text: text, userExamples: folderContext.isEmpty ? nil : folderContext)
        
        // Temporarily set content for smartSort
        try req.content.encode(aiRequest)
        let analysis = try await smartSortController.smartSort(req: req)
        
        // 3. Find or create folder
        let folderName = analysis.folders.first ?? "Uncategorized"
        let folder = try await Folder.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .filter(\.$name == folderName)
            .first()
        
        let targetFolder: Folder
        if let existingFolder = folder {
            targetFolder = existingFolder
        } else {
            targetFolder = Folder(userId: user.id!, name: folderName)
            try await targetFolder.save(on: req.db)
        }
        
        // 4. Create bookmark
        let bookmark = Bookmark(
            userId: user.id!,
            folderId: targetFolder.id,
            url: data.url,
            title: data.title,
            notes: data.notes
        )
        try await bookmark.save(on: req.db)
        
        return SavedBookmarkResponse(
            bookmark: bookmark,
            folder: targetFolder,
            analysis: analysis
        )
    }
    
    func index(req: Request) async throws -> [Bookmark] {
        let user = try req.auth.require(User.self)
        return try await Bookmark.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .all()
    }
    
    func delete(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        guard let bookmarkID = req.parameters.get("bookmarkID", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        guard let bookmark = try await Bookmark.find(bookmarkID, on: req.db) else {
            throw Abort(.notFound)
        }
        
        guard bookmark.$user.id == user.id else {
            throw Abort(.forbidden)
        }
        
        try await bookmark.delete(on: req.db)
        return .ok
    }
}

struct AnalyzeAndSaveRequest: Content {
    let url: String
    let title: String?
    let notes: String?
}

struct SavedBookmarkResponse: Content {
    let bookmark: Bookmark
    let folder: Folder
    let analysis: AIAnalysisResult
}
