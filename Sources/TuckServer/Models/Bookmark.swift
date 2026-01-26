import Vapor
import Fluent

final class Bookmark: Model, Content, @unchecked Sendable {
    static let schema = "bookmarks"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "user_id")
    var user: User
    
    @OptionalParent(key: "folder_id")
    var folder: Folder?
    
    @Field(key: "url")
    var url: String
    
    @OptionalField(key: "title")
    var title: String?
    
    @OptionalField(key: "notes")
    var notes: String?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    init() {}
    
    init(id: UUID? = nil, userId: UUID, folderId: UUID? = nil, url: String, title: String? = nil, notes: String? = nil) {
        self.id = id
        self.$user.id = userId
        self.$folder.id = folderId
        self.url = url
        self.title = title
        self.notes = notes
    }
}
