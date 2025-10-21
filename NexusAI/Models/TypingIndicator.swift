import Foundation
import FirebaseFirestore

struct TypingIndicator: Codable, Identifiable {
    @DocumentID var id: String?
    let conversationId: String
    let userId: String
    let userName: String
    var isTyping: Bool
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId
        case userId
        case userName
        case isTyping
        case timestamp
    }
}
