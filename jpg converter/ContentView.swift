//
//  ContentView.swift
//  jpg converter
//
//  Created by Maicol Cabreja on 8/31/25.
//

import SwiftUI
import GoogleMobileAds
import AppTrackingTransparency
import AdSupport
import PhotosUI
import RevenueCatUI

// MARK: - Main Tab View
struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
        }
        .accentColor(.accentColor)
    }
}

// MARK: - Home View
@MainActor
struct HomeView: View {
    @StateObject private var viewModel = ImageConverterViewModel()
    @EnvironmentObject private var interstitialAdManager: InterstitialAdManager
    @Environment(\.requestReview) private var requestReview
    @EnvironmentObject private var store: Store
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var sessionStart = Date()
    @State private var hasPromptedForReview = false
    @State private var hasPresentedMainPaywallThisSession = false
    @State private var showMainPaywall = false

    private var maxPickerSelectionCount: Int {
        store.isPremium ? 15 : 1
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 14) {
                        // Image Selection Area
                        imageSelectionView
                            .sectionCard()
                        
                        
                        // Selected Images Grid
                        if !viewModel.selectedImages.isEmpty {
                            selectedImagesView
                                .sectionCard()
                                .transition(.opacity)
                        }
                        
                        // Target Format Selection
                        if !viewModel.selectedImages.isEmpty {
                            targetFormatSelectionView
                                .sectionCard()
                                .transition(.opacity)
                        }
                        
                        // Conversion Controls
                        if !viewModel.selectedImages.isEmpty {
                            conversionControlsView
                                .sectionCard()
                                .transition(.opacity)
                        }
                        
                        // Results Section
                        if !viewModel.selectedImages.isEmpty && viewModel.selectedImages.contains(where: { $0.convertedImage != nil }) {
                            resultsSectionView
                                .sectionCard()
                                .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 84)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("JPG Converter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showMainPaywall = true
                    } label: {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.accentColor)
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onChange(of: selectedPhotos) { oldValue, newValue in
            Task {
                await loadPhotosFromPicker(newValue)
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .alert("Success", isPresented: $viewModel.showSuccess) {
            Button("OK") { }
        } message: {
            Text(viewModel.successMessage)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if !hasPromptedForReview && Date().timeIntervalSince(sessionStart) > 45 {
                maybeRequestReview()
            }
        }
        .onChange(of: viewModel.shouldShowInterstitial) { oldValue, newValue in
            if newValue && interstitialAdManager.isAdReady {
                let rootVC = UIApplication.shared.getRootViewController()
                interstitialAdManager.showInterstitial(from: rootVC)
                viewModel.shouldShowInterstitial = false
            }
        }
        .onAppear {
            store.loadStoredPurchases()
            viewModel.store = store
            sessionStart = Date()
            maybePresentMainPaywall()
        }
        .sheet(isPresented: $showMainPaywall) {
            PaywallView()
        }
    }
    
    func maybeRequestReview() {
        let lastPromptDate = UserDefaults.standard.object(forKey: "LastReviewPromptDate") as? Date
        let now = Date()
        let minInterval: TimeInterval = 60 * 60 * 24 * 30 // 30 days
        
        if lastPromptDate == nil || now.timeIntervalSince(lastPromptDate!) > minInterval {
            requestReview()
            UserDefaults.standard.set(now, forKey: "LastReviewPromptDate")
            hasPromptedForReview = true
        }
    }

    private func maybePresentMainPaywall() {
        guard !store.isPremium else { return }
        guard !hasPresentedMainPaywallThisSession else { return }

        hasPresentedMainPaywallThisSession = true
        showMainPaywall = true
    }
    
    // MARK: - Helper Methods
    private func saveAllConvertedImages() async {
        await viewModel.exportAllImages()
    }
    
    private func loadPhotosFromPicker(_ items: [PhotosPickerItem]) async {
        var images: [UIImage] = []
        
        for item in items {
            if let imageData = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: imageData) {
                images.append(makeIndependentImage(from: image))
            }
        }
        
        await MainActor.run {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                viewModel.addImagesFromPhotos(images)
            }
            selectedPhotos.removeAll()
        }
    }
    
    private func makeIndependentImage(from image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
    
    private var imageSelectionView: some View {
        VStack(spacing: 8) {
            Text("Select Images to Convert")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 16) {
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: maxPickerSelectionCount,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.1))
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: "photo.on.rectangle")
                                .font(.title)
                                .foregroundColor(.accentColor)
                        }
                        
                        VStack(spacing: 4) {
                            Text("Select Photos")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text(store.isPremium ? "Pick up to 15 at a time" : "Free: 1 photo at a time")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 3]))
                                    .foregroundColor(.accentColor.opacity(0.4))
                            )
                    )
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                }
                .scaleEffect(selectedPhotos.isEmpty ? 1.0 : 0.95)
                .animation(.easeInOut(duration: 0.2), value: selectedPhotos.isEmpty)
                
            }
            
            // Dotted outline placeholder when no images selected
            if viewModel.selectedImages.isEmpty {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.secondary.opacity(0.1))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.title2)
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    
                    VStack(spacing: 4) {
                        Text("No Images Selected")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text("Selected images will appear here")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 112)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6).opacity(0.3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 3]))
                                .foregroundColor(.secondary.opacity(0.3))
                        )
                )
                .shadow(color: .black.opacity(0.02), radius: 4, x: 0, y: 1)
            }
        }
    }
    
    private var selectedImagesView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Selected Images (\(viewModel.selectedImages.count))")
                    .font(.headline)
                
                Spacer()
                
                Button("Clear All") {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        viewModel.clearAllImages()
                    }
                }
                .buttonStyle(.plain)
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.12))
                .foregroundColor(.red)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(Array(viewModel.selectedImages.chunked(into: 3).enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(row) { imageModel in
                            SelectedImageView(
                                imageModel: imageModel,
                                onRemove: {
                                    viewModel.removeImage(id: imageModel.id)
                                }
                            )
                        }

                        if row.count < 3 {
                            ForEach(0..<(3 - row.count), id: \.self) { _ in
                                Color.clear
                                    .frame(width: 100, height: 100)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var targetFormatSelectionView: some View {
        VStack(spacing: 10) {
            Text("Choose Output Format")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Select the format you want to convert your images to")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ConversionDirection.fromAny.targetFormats) { format in
                        CompactFormatButton(
                            format: format,
                            isSelected: viewModel.targetFormat == format,
                            action: {
                                viewModel.setTargetFormat(format)
                            }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private var conversionControlsView: some View {
        VStack(spacing: 10) {
            Button(action: {
                Task {
                    await viewModel.convertImages()
                }
            }) {
                HStack {
                    if viewModel.isConverting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    
                    Text(viewModel.isConverting ? "Converting..." : "Convert to \(viewModel.targetFormat.displayName)")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.red, Color.pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(viewModel.isConverting)
            
            if viewModel.isConverting {
                ProgressView(value: viewModel.conversionProgress)
                    .progressViewStyle(LinearProgressViewStyle())
            }
        }
    }
    
    private var resultsSectionView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Converted to \(viewModel.targetFormat.displayName)")
                    .font(.headline)
                    .foregroundColor(.green)
                
                Spacer()
                
                Button(action: {
                    Task {
                        await saveAllConvertedImages()
                    }
                }) {
                    HStack(spacing: 6) {
                        if viewModel.isExporting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "square.and.arrow.down")
                        }
                        Text(viewModel.isExporting ? "Saving..." : "Save All")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(viewModel.isExporting ? Color.gray : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(viewModel.isExporting)
            }
            
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(Array(viewModel.selectedImages.filter { $0.convertedImage != nil }.chunked(into: 3).enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(row) { imageModel in
                            SimplifiedConvertedImageView(imageModel: imageModel)
                        }

                        if row.count < 3 {
                            ForEach(0..<(3 - row.count), id: \.self) { _ in
                                Color.clear
                                    .frame(width: 100, height: 124)
                            }
                        }
                    }
                }
            }
            
            let convertedCount = viewModel.selectedImages.filter({ $0.convertedImage != nil }).count
            if convertedCount > 1 {
                bulkActionButtons
            }
        }
    }
    
    private var bulkActionButtons: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button(action: {
                    Task {
                        await saveAllConvertedImages()
                    }
                }) {
                    HStack(spacing: 6) {
                        if viewModel.isExporting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "square.and.arrow.down")
                        }
                        Text(viewModel.isExporting ? "Saving..." : "Save All")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.isExporting ? Color.gray : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(viewModel.isExporting)
                
                Button(action: {
                    Task {
                        var shareItems: [Any] = []
                        for imageModel in viewModel.selectedImages {
                            if let convertedImage = imageModel.convertedImage,
                               let convertedFormat = imageModel.convertedFormat {
                                let items = await viewModel.shareImage(convertedImage, format: convertedFormat)
                                shareItems.append(contentsOf: items)
                            }
                        }
                        
                        if !shareItems.isEmpty {
                            let activityVC = UIActivityViewController(activityItems: shareItems, applicationActivities: nil)
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let window = windowScene.windows.first {
                                window.rootViewController?.present(activityVC, animated: true)
                            }
                        }
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share All")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            
            // Export Progress Bar
            if viewModel.isExporting {
                VStack(spacing: 8) {
                    HStack {
                        Text("Exporting images...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(viewModel.exportProgress, format: .percent.precision(.fractionLength(0)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: viewModel.exportProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .green))
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemGray5))
        .cornerRadius(12)
    }
}

struct CompactFormatButton: View {
    let format: ConversionFormat
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: formatIcon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                
                Text(format.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .frame(width: 70, height: 60)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemGray5))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : Color(.systemGray4), lineWidth: isSelected ? 2 : 0.5)
            )
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var formatIcon: String {
        switch format {
        case .jpg: return "photo.fill"
        case .png: return "photo.fill"
        case .heic: return "photo.badge.plus"
        case .tiff: return "photo.artframe"
        }
    }
}

struct SelectedImageView: View {
    let imageModel: ImageConversionModel
    let onRemove: () -> Void
    
    var body: some View {
        ZStack {
            Image(uiImage: imageModel.originalImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
                .clipped()
                .cornerRadius(10)
            
            VStack {
                HStack {
                    Spacer()
                    
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
                
                Spacer()
            }
            .padding(8)
            
            if imageModel.isProcessing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
                    .transition(.scale.combined(with: .opacity))
            }
            
            if imageModel.errorMessage != nil {
                VStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                    
                    Text("Error")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .background(Color.black.opacity(0.6))
                .cornerRadius(8)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 100, height: 100)
    }
}

struct SimplifiedConvertedImageView: View {
    let imageModel: ImageConversionModel
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if let convertedImage = imageModel.convertedImage {
                    Image(uiImage: convertedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipped()
                        .cornerRadius(8)
                }
                
                VStack {
                    HStack {
                        Spacer()
                        
                        Text(imageModel.convertedFormat?.displayName.uppercased() ?? "")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                }
                .padding(6)
            }
            
            Text("\(imageModel.originalFormat.displayName) → \(imageModel.convertedFormat?.displayName ?? "")")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
    }
}

private extension View {
    func sectionCard() -> some View {
        self
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 6)
    }
}

private extension Array where Element == ImageConversionModel {
    func chunked(into size: Int) -> [[ImageConversionModel]] {
        stride(from: 0, to: count, by: size).map { index in
            Array(self[index..<Swift.min(index + size, count)])
        }
    }
}
