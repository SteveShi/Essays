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

extension Error {
    var isCancellationLike: Bool {
        if self is CancellationError {
            return true
        }

        if let urlError = self as? URLError, urlError.code == .cancelled {
            return true
        }

        let nsError = self as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}
