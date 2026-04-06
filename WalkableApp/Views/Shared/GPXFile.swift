import SwiftUI
import UniformTypeIdentifiers

struct GPXFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .xml) { file in
            SentTransferredFile(file.url)
        }
    }
}
