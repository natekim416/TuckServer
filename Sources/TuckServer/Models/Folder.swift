import Vapor
import Fluent

final class Folder: Model, Content, @unchecked Sendable {
    static let schema = "folders"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "user_id")
    var user: User
    
    @Field(key: "name")
    var name: String
    
    @OptionalField(key: "color")
    var color: String?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Children(for: \.$folder)
    var bookmarks: [Bookmark]
    
    init() {}
    
    init(id: UUID? = nil, userId: UUID, name: String, color: String? = nil) {
        self.id = id
        self.$user.id = userId
        self.name = name
        self.color = color
    }
}
