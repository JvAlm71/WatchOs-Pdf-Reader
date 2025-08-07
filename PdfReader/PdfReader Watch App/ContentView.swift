
//
//  ContentView.swift
//  (Arquivo com a correção de rotação da imagem)
//

import SwiftUI
import CoreGraphics

struct ContentView: View {
    @State private var isShowingPDF = false
    let pdfFileName = "documento.pdf"

    var body: some View {
        VStack {
            Image(systemName: "doc.text.fill")
                .font(.largeTitle)
                .foregroundColor(.accentColor)
                .padding()

            Text("Visualizador de PDF")
                .font(.headline)

            Button("Abrir PDF") {
                isShowingPDF.toggle()
            }
            .padding(.top)
        }
        .sheet(isPresented: $isShowingPDF) {
            PDFPageView(fileName: pdfFileName)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct PDFPageView: View {
    let fileName: String
    
    @State private var pdfImages: [UIImage] = []
    
    @State private var zoomScale: CGFloat = 1.0
    @FocusState private var isViewFocused: Bool
    
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack {
                if pdfImages.isEmpty {
                    ProgressView("Carregando PDF...")
                        .onAppear(perform: loadPDF)
                } else {
                    ScrollView([.vertical, .horizontal]) {
                        VStack(spacing: 4) {
                            ForEach(pdfImages, id: \.self) { image in
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            }
                        }
                        .scaleEffect(zoomScale)
                    }
                    .focusable()
                    .focusEffectDisabled()
                    .digitalCrownRotation($zoomScale, from: 1.0, through: 5.0, by: 0.1, sensitivity: .high, isContinuous: false, isHapticFeedbackEnabled: true)
                    .onAppear {
                        isViewFocused = true
                    }
                }
            }
            .navigationTitle("Documento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }

    /// Carrega e renderiza o PDF usando CoreGraphics.
    private func loadPDF() {
        guard let pdfURL = Bundle.main.url(forResource: fileName.replacingOccurrences(of: ".pdf", with: ""), withExtension: "pdf"),
              let pdfDocument = CGPDFDocument(pdfURL as CFURL) else {
            print("Erro: PDF não encontrado ou não pôde ser aberto.")
            return
        }

        var images: [UIImage] = []
        for pageNumber in 1...pdfDocument.numberOfPages {
            guard let page = pdfDocument.page(at: pageNumber) else { continue }
            
            let pageRect = page.getBoxRect(.mediaBox)
            
            let image = renderPageToImage(page: page, size: pageRect.size, scale: 2.0)
            images.append(image)
        }
        
        self.pdfImages = images
    }
    
    /// Função auxiliar para renderizar uma única página de PDF em uma UIImage.
    private func renderPageToImage(page: CGPDFPage, size: CGSize, scale: CGFloat) -> UIImage {
        let scaledSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        guard let context = CGContext(
            data: nil,
            width: Int(scaledSize.width),
            height: Int(scaledSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return UIImage()
        }

        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: scaledSize))
        
  
        let transform = page.getDrawingTransform(.mediaBox, rect: CGRect(origin: .zero, size: scaledSize), rotate: 0, preserveAspectRatio: true)
        context.concatenate(transform)

        
        // Agora, desenhamos o PDF no contexto já transformado corretamente.
        context.drawPDFPage(page)
        
        guard let cgImage = context.makeImage() else { return UIImage() }
        
        return UIImage(cgImage: cgImage)
    }
}
