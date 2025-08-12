//
//  ContentView.swift
//
//

import SwiftUI
import CoreGraphics

struct ContentView: View {
    @State private var isShowingPDF = false
    @State private var pdfFiles: [String] = []            // Vetor com nomes (ex: "arquivo.pdf")
    @State private var selectedPDF: String? = nil         // PDF escolhido

    var body: some View {
        NavigationView {
            Group {
                if pdfFiles.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Procurando PDFs no app...")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List(pdfFiles, id: \.self) { file in
                        Button {
                            selectedPDF = file
                            isShowingPDF = true
                        } label: {
                            HStack {
                                Image(systemName: "doc.text")
                                Text(file.replacingOccurrences(of: ".pdf", with: ""))
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.carousel)
                }
            }
            .navigationTitle("PDFs")
        }
        .onAppear(perform: loadPDFFiles)
        .sheet(isPresented: $isShowingPDF) {
            if let selectedPDF {
                PDFPageView(fileName: selectedPDF)
            } else {
                Text("Erro ao carregar PDF").padding()
            }
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
    @State private var crownZoom: Double = 1.0
    private let minZoom: Double = 1.0
    private let maxZoom: Double = 10.0
    private let presetZooms: [Double] = [1.0, 1.5, 2.0, 2.5]
    
    private var appliedZoom: CGFloat { isZoomMode ? CGFloat(crownZoom) : 1.0 } // Só aplica se modo ativo
    
    @State private var isZoomMode: Bool = false
    @State private var showZoomHUD: Bool = false
    @State private var hudWorkItem: DispatchWorkItem?
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                Group {
                    if pdfImages.isEmpty {
                        ProgressView("Carregando PDF...")
                            .onAppear(perform: loadPDF)
                    } else {
                        scrollView
                    }
                }
                
                // Botão modo Zoom
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isZoomMode.toggle()
                            }
                            if !isZoomMode {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    crownZoom = 1.0 
                                }
                                showZoomHUD = false
                            } else {
                                flashZoomHUD()
                            }
                        } label: {
                            Image(systemName: isZoomMode ? "magnifyingglass.circle.fill" : "magnifyingglass.circle")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.accentColor)
                                .padding(6)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .padding([.top, .trailing], 6)
                    }
                    Spacer()
                }
                
                if showZoomHUD && isZoomMode {
                    Text(String(format: "Zoom %.1fx", crownZoom))
                        .font(.caption2)
                        .padding(6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .transition(.opacity.combined(with: .scale))
                        .padding(.bottom, 8)
                        .frame(maxHeight: .infinity, alignment: .bottom)
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
            .onChange(of: crownZoom) { _, _ in
                if isZoomMode { flashZoomHUD() }
            }
        }
    }
    
    // Scroll principal (condicionalmente recebe Digital Crown)
    private var scrollView: some View {
        let content = ScrollView([.vertical, .horizontal]) {
            VStack(spacing: 4) {
                ForEach(pdfImages, id: \.self) { image in
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(.horizontal, 4)
                }
            }
            .scaleEffect(appliedZoom)
            .animation(.easeInOut(duration: 0.15), value: appliedZoom)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                guard isZoomMode else { return }
                withAnimation(.spring()) {
                    advancePresetZoom()
                    flashZoomHUD()
                }
            }
        }
        
        return Group {
            if isZoomMode {
                content
                    .focusable(true)
                    .digitalCrownRotation(
                        $crownZoom,
                        from: minZoom,
                        through: maxZoom,
                        by: 0.05,
                        sensitivity: .medium,
                        isContinuous: false,
                        isHapticFeedbackEnabled: true
                    )
            } else {
                content
            }
        }
    }
    
    private func flashZoomHUD() {
        hudWorkItem?.cancel()
        showZoomHUD = true
        let item = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.25)) {
                showZoomHUD = false
            }
        }
        hudWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: item)
    }
    
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
            images.append(renderPageToImage(page: page, size: pageRect.size, scale: 2.0))
        }
        pdfImages = images
    }
    
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
        ) else { return UIImage() }
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: scaledSize))
        let transform = page.getDrawingTransform(.mediaBox, rect: CGRect(origin: .zero, size: scaledSize), rotate: 0, preserveAspectRatio: true)
        context.concatenate(transform)
        context.drawPDFPage(page)
        guard let cgImage = context.makeImage() else { return UIImage() }
        return UIImage(cgImage: cgImage)
    }
    
    private func advancePresetZoom() {
        let current = crownZoom
        let eps = 0.011
        if let idx = presetZooms.firstIndex(where: { abs($0 - current) < eps }) {
            let next = presetZooms[(idx + 1) % presetZooms.count]
            crownZoom = min(max(next, minZoom), maxZoom)
        } else {
            let next = presetZooms.first(where: { $0 > current + eps }) ?? presetZooms.first!
            crownZoom = min(max(next, minZoom), maxZoom)
        }
    }
}

// MARK: - Helper (fora das structs para organização opcional)
private extension ContentView {
    func loadPDFFiles() {
        // Busca todos os PDFs no bundle principal
        if let urls = Bundle.main.urls(forResourcesWithExtension: "pdf", subdirectory: nil) {
            let names = urls.map { $0.lastPathComponent }.sorted()
            pdfFiles = names
        } else {
            pdfFiles = []
        }
    }
}
