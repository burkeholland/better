import SwiftUI
import PDFKit

struct PDFViewer: View {
    let url: URL?
    let data: Data?
    @Environment(\.dismiss) private var dismiss
    @State private var pdfDocument: PDFDocument?
    @State private var errorMessage: String?

    init(url: URL) {
        self.url = url
        self.data = nil
    }

    init(data: Data) {
        self.data = data
        self.url = nil
    }

    var body: some View {
        NavigationStack {
            Group {
                if let pdfDocument {
                    PDFKitRepresentedView(document: pdfDocument)
                        .ignoresSafeArea(edges: .bottom)
                } else if let errorMessage {
                    ContentUnavailableView {
                        Label("Unable to Load PDF", systemImage: "doc.questionmark")
                    } description: {
                        Text(errorMessage)
                    }
                } else {
                    ProgressView("Loading PDF…")
                }
            }
            .navigationTitle("PDF Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }

                if let url {
                    ToolbarItem(placement: .topBarLeading) {
                        ShareLink(item: url)
                    }
                }
            }
        }
        .task {
            await loadPDF()
        }
    }

    private func loadPDF() async {
        if let data {
            if let doc = PDFDocument(data: data) {
                pdfDocument = doc
            } else {
                errorMessage = "The PDF data could not be read."
            }
            return
        }

        guard let url else {
            errorMessage = "No PDF source provided."
            return
        }

        if url.isFileURL {
            if let doc = PDFDocument(url: url) {
                pdfDocument = doc
            } else {
                errorMessage = "The PDF file could not be opened."
            }
            return
        }

        // Remote URLs: download data first
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let doc = PDFDocument(data: data) {
                pdfDocument = doc
            } else {
                errorMessage = "The downloaded file is not a valid PDF."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - PDFKit Wrapper

struct PDFKitRepresentedView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.document = document
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document !== document {
            uiView.document = document
        }
    }
}
