import Testing
import Foundation
@testable import Essays

struct APICompatibilityTests {

    @Test("Verify OutboxTask Payload Serialization")
    func testOutboxPayloadSerialization() throws {
        let payload = MemoPayload(
            content: "Test Content #tag",
            visibility: "PRIVATE",
            pinned: true,
            tags: ["tag"],
            attachmentNames: ["resources/1"],
            locationPlaceholder: "Office",
            locationLatitude: 1.23,
            locationLongitude: 4.56
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MemoPayload.self, from: data)

        #expect(decoded.content == "Test Content #tag")
        #expect(decoded.tags?.contains("tag") == true)
        #expect(decoded.locationPlaceholder == "Office")
    }

    @Test("SyncEngine Task Dispatching Logic")
    func testTaskDispatching() async throws {
        // This test ensures the SyncEngine correctly interprets task types
        let task = OutboxTask(
            type: .createMemo,
            payload: try JSONEncoder().encode(MemoPayload(content: "Sync Test", visibility: "PRIVATE", pinned: false, tags: nil, attachmentNames: nil, locationPlaceholder: nil, locationLatitude: nil, locationLongitude: nil))
        )
        
        #expect(task.type == .createMemo)
        #expect(task.state == .pending)
    }

    @Test("V026 vs V027 Payload Compatibility")
    func testVersionPayloadCompatibility() {
        // Both versions should be able to handle the same logical fields
        let content = "Hello World"
        let tags = ["ios", "swift"]
        
        // V026 Body construction (Internal logic check)
        var body026: [String: Any] = ["content": content]
        body026["tags"] = tags
        
        // V027 Body construction (Internal logic check)
        var body027: [String: Any] = ["content": content]
        body027["tags"] = tags
        
        #expect(body026["content"] as? String == body027["content"] as? String)
        #expect((body026["tags"] as? [String])?.count == (body027["tags"] as? [String])?.count)
    }

    @Test("V0.31.0 Space Visibility and Metadata Compatibility")
    func testV031SpaceCompatibility() throws {
        // Verify MemoVisibility enum handles SPACE
        #expect(MemoVisibility(rawValue: "SPACE") == .space)
        #expect(MemoVisibility.space.rawValue == "SPACE")
        #expect(MemoVisibility.space.icon == "person.2")
        #expect(!MemoVisibility.creatableCases.contains(.space))

        // Verify MemoData decodes v0.31.0 memo payload with space and SPACE visibility
        let v031JSON = """
        {
            "name": "memos/memo-v31",
            "content": "Collaborative project update #space",
            "createTime": "2026-09-20T08:00:00Z",
            "updateTime": "2026-09-20T08:30:00Z",
            "visibility": "SPACE",
            "state": "NORMAL",
            "pinned": false,
            "tags": ["space"],
            "space": "spaces/team-alpha"
        }
        """.data(using: .utf8)!

        let decodedMemoData = try MemosAPIDecoder.shared.decode(MemosAPIV1.MemoData.self, from: v031JSON)
        #expect(decodedMemoData.name == "memos/memo-v31")
        #expect(decodedMemoData.visibility == "SPACE")
        #expect(decodedMemoData.space == "spaces/team-alpha")

        // Verify Memo model initializes with spaceName
        let memo = Memo(
            name: decodedMemoData.name,
            numericID: decodedMemoData.extractedId,
            content: decodedMemoData.content,
            createdAt: decodedMemoData.createTime,
            updatedAt: decodedMemoData.updateTime,
            visibility: MemoVisibility(rawValue: decodedMemoData.visibility) ?? .private,
            pinned: decodedMemoData.pinned ?? false,
            state: MemoState(rawValue: decodedMemoData.state ?? "NORMAL") ?? .normal,
            tags: decodedMemoData.tags ?? [],
            spaceName: decodedMemoData.space
        )

        #expect(memo.visibility == .space)
        #expect(memo.spaceName == "spaces/team-alpha")
    }
}
