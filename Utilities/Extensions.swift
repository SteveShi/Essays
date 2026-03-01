import Foundation

extension Collection {
    /// Chunks the collection into arrays of a given size.
    func chunked(into size: Int) -> [[Element]] {
        var chunks: [[Element]] = []
        var index = self.startIndex
        while index < self.endIndex {
            let nextIndex = self.index(index, offsetBy: size, limitedBy: self.endIndex) ?? self.endIndex
            chunks.append(Array(self[index..<nextIndex]))
            index = nextIndex
        }
        return chunks
    }
}
