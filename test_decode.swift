import Foundation

let jsonString = """
{
  "name": "memos/Zsa5wX9MCVtUjtfMsXdnrZ",
  "content": "Geaux Tigers!",
  "createTime": "2026-02-25T20:30:59Z",
  "updateTime": "2026-02-25T20:30:59Z",
  "visibility": "PUBLIC",
  "resources": [
    {
      "name": "resources/123",
      "filename": "image.png",
      "type": "image/png",
      "size": 1024
    }
  ],
  "attachments": [
    {
      "name": "resources/123",
      "filename": "image.png",
      "type": "image/png",
      "size": 1024
    }
  ]
}
"""

struct Attachment: Codable, Identifiable, Hashable {
    let name: String
    let filename: String
    let type: String
    let size: Int64
    var externalLink: String?
    let createTime: Date?
    let memo: String?

    var id: String { name }
}

struct MemoData: Decodable {
    let name: String
    let content: String
    let attachments: [Attachment]?
    let resources: [Attachment]?
}

let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase
decoder.dateDecodingStrategy = .iso8601
do {
    let data = try decoder.decode(MemoData.self, from: jsonString.data(using: .utf8)!)
    print("Decoded successfully! attachments: \(String(describing: data.attachments?.count)), resources: \(String(describing: data.resources?.count))")
} catch {
    print("Decoding error JSON: \(error)")
}
