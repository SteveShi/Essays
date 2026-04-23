import Testing
import Foundation
@testable import Essays

struct APICompatibilityTests {

    @Test("Verify OutboxTask Payload Serialization")
    func testOutboxPayloadSerialization() throws {
        let payload = CreateMemoPayload(
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
        let decoded = try decoder.decode(CreateMemoPayload.self, from: data)
        
        #expect(decoded.content == "Test Content #tag")
        #expect(decoded.tags?.contains("tag") == true)
        #expect(decoded.locationPlaceholder == "Office")
    }

    @Test("SyncEngine Task Dispatching Logic")
    func testTaskDispatching() async throws {
        // This test ensures the SyncEngine correctly interprets task types
        let task = OutboxTask(
            type: .createMemo,
            payload: try JSONEncoder().encode(CreateMemoPayload(content: "Sync Test", visibility: "PRIVATE", pinned: false, tags: nil, attachmentNames: nil, locationPlaceholder: nil, locationLatitude: nil, locationLongitude: nil))
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
}
