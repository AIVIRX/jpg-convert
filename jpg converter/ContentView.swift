//
//  ContentView.swift
//  jpg converter
//
//  Created by Maicol Cabreja on 8/31/25.
//

import SwiftUI
import PhotosUI

struct TransferableImage: Transferable {
    let uiImage: UIImage
    
    enum TransferError: Error {
        case importFailed
    }
    
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            guard let uiImage = UIImage(data: data) else {
                throw TransferError.importFailed
            }
            return TransferableImage(uiImage: uiImage)
        }
    }
}

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
struct HomeView: View {
    @StateObject private var viewModel = ImageConverterViewModel()
    @State private var showFilesPicker = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        // Image Selection Area
                        imageSelectionView
                        
                        // Selected Images Grid
                        if !viewModel.selectedImages.isEmpty {
                            selectedImagesView
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.7).combined(with: .opacity),
                                    removal: .scale(scale: 0.9).combined(with: .opacity)
                                ))
                                .animation(.spring(response: 0.7, dampingFraction: 0.6), value: viewModel.selectedImages.count)
                        }
                        
                        // Target Format Selection
                        if !viewModel.selectedImages.isEmpty {
                            targetFormatSelectionView
                                .transition(.asymmetric(
                                    insertion: .move(edge: .leading).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.selectedImages.count)
                        }
                        
                        // Conversion Controls
                        if !viewModel.selectedImages.isEmpty {
                            conversionControlsView
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .trailing).combined(with: .opacity)
                                ))
                                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.selectedImages.count)
                        }
                        
                        // Results Section
                        if !viewModel.selectedImages.isEmpty && viewModel.selectedImages.contains(where: { $0.convertedImage != nil }) {
                            resultsSectionView
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                                    removal: .scale(scale: 0.95).combined(with: .opacity)
                                ))
                                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.selectedImages.contains(where: { $0.convertedImage != nil }))
                        }
                        
                        // Pro Upgrade Banner
                        if !viewModel.isProUser {
                            proUpgradeBanner
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $viewModel.showProUpgrade) {
            ProUpgradeView()
        }
        .onChange(of: selectedPhotos) { oldValue, newValue in
            Task {
                await loadPhotosFromPicker(newValue)
            }
        }
        .sheet(isPresented: $showFilesPicker) {
            FilesPickerView(isPresented: $showFilesPicker) { urls in
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    viewModel.addImagesFromFiles(urls)
                }
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
    }
    
    // MARK: - Helper Methods
    private func saveAllConvertedImages() async {
        for imageModel in viewModel.selectedImages {
            if let convertedImage = imageModel.convertedImage,
               let convertedFormat = imageModel.convertedFormat {
                if convertedFormat == .pdf {
                    await viewModel.exportToFiles(convertedImage, format: convertedFormat, imageModel: imageModel)
                } else {
                    await viewModel.exportToPhotos(convertedImage, format: convertedFormat)
                }
            }
        }
    }
    
    private func loadPhotosFromPicker(_ items: [PhotosPickerItem]) async {
        var images: [UIImage] = []
        
        for item in items {
            if let transferableImage = try? await item.loadTransferable(type: TransferableImage.self) {
                let image = transferableImage.uiImage
                let correctedImage = fixImageOrientation(image)
                images.append(correctedImage)
            }
        }
        
        await MainActor.run {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                viewModel.addImagesFromPhotos(images)
            }
            selectedPhotos.removeAll()
        }
    }
    
    private func fixImageOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage ?? image
    }
    
    // MARK: - View Components
    private var imageSelectionView: some View {
        VStack(spacing: 10) {
            Text("Select Images to Convert")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Convert JPEG, PNG, HEIC and more to any format")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 16) {
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 10,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                        
                        Text("Photos")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 0.5)
                    )
                    .cornerRadius(12)
                }
                .scaleEffect(selectedPhotos.isEmpty ? 1.0 : 0.95)
                .animation(.easeInOut(duration: 0.2), value: selectedPhotos.isEmpty)
                
                Button(action: {
                    showFilesPicker = true
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "folder")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                        
                        Text("Files")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 0.5)
                    )
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private var selectedImagesView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Selected Images (\(viewModel.selectedImages.count))")
                    .font(.headline)
                
                Spacer()
                
                Button("Clear All") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        viewModel.clearAllImages()
                    }
                }
                .foregroundColor(.red)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(Array(viewModel.selectedImages.enumerated()), id: \.element.id) { index, imageModel in
                    SelectedImageView(
                        imageModel: imageModel,
                        onRemove: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                viewModel.removeImage(at: index)
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.3).combined(with: .opacity).combined(with: .slide),
                        removal: .scale(scale: 0.5).combined(with: .opacity)
                    ))
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.1), value: viewModel.selectedImages.count)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.selectedImages.count)
        }
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        ))
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.selectedImages.count)
    }
    
    private var targetFormatSelectionView: some View {
        VStack(spacing: 16) {
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
        VStack(spacing: 16) {
            if viewModel.canUseCompressionSlider {
                compressionQualityView
            }
            
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
                .background(Color.accentColor)
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
    
    private var compressionQualityView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Quality")
                    .font(.subheadline)
                
                Spacer()
                
                Text("\(Int(viewModel.compressionQuality * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Slider(value: $viewModel.compressionQuality, in: 0.1...1.0, step: 0.1)
                .accentColor(.accentColor)
        }
    }
    
    private var resultsSectionView: some View {
        VStack(spacing: 16) {
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
                        Image(systemName: "square.and.arrow.down")
                        Text("Save All")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(viewModel.selectedImages.filter { $0.convertedImage != nil }) { imageModel in
                    SimplifiedConvertedImageView(imageModel: imageModel)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity).combined(with: .slide),
                            removal: .scale(scale: 0.5).combined(with: .opacity)
                        ))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.selectedImages.count)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.selectedImages.count)
            
            let convertedCount = viewModel.selectedImages.filter({ $0.convertedImage != nil }).count
            if convertedCount > 1 {
                bulkActionButtons
            }
        }
    }
    
    private var bulkActionButtons: some View {
        VStack(spacing: 12) {
            Text("Bulk Actions")
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                Button(action: {
                    Task {
                        await saveAllConvertedImages()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.down")
                        Text("Save All")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
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
        }
        .padding()
        .background(Color(.systemGray5))
        .cornerRadius(12)
    }
    
    private var proUpgradeBanner: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                
                Text("Upgrade to Pro")
                    .font(.headline)
                
                Spacer()
                
                Button("Upgrade") {
                    viewModel.requestProUpgrade()
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            Text("Unlock batch JPEG conversion, quality control, and unlimited conversions")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemGray5))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
        .cornerRadius(12)
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @StateObject private var viewModel = ImageConverterViewModel()
    
    var body: some View {
        NavigationView {
            List {
                Section("App Info") {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                            .foregroundColor(.green)
                        Text("Supported Formats")
                        Spacer()
                        Text("JPEG, PNG, HEIC, TIFF, PDF")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section("Pro Features") {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("Pro Status")
                        Spacer()
                        Text(viewModel.isProUser ? "Active" : "Inactive")
                            .foregroundColor(viewModel.isProUser ? .green : .red)
                    }
                    
                    if !viewModel.isProUser {
                        Button(action: {
                            viewModel.requestProUpgrade()
                        }) {
                            HStack {
                                Image(systemName: "star.circle.fill")
                                    .foregroundColor(.yellow)
                                Text("Upgrade to Pro")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section("Support") {
                    Button(action: {
                        // Open support email or website
                    }) {
                        HStack {
                            Image(systemName: "envelope")
                                .foregroundColor(.blue)
                            Text("Contact Support")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: {
                        // Open privacy policy
                    }) {
                        HStack {
                            Image(systemName: "hand.raised")
                                .foregroundColor(.green)
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: {
                        // Open terms of service
                    }) {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.orange)
                            Text("Terms of Service")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $viewModel.showProUpgrade) {
            ProUpgradeView()
        }
    }
}

// MARK: - Compact Format Button
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
        case .pdf: return "doc.text.fill"
        case .tiff: return "photo.artframe"
        }
    }
}

// MARK: - Selected Image View
struct SelectedImageView: View {
    let imageModel: ImageConversionModel
    let onRemove: () -> Void
    @State private var isPressed = false
    
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
                    .scaleEffect(isPressed ? 0.9 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isPressed)
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
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
            }
        }
    }
}

// MARK: - Simplified Converted Image View
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

// MARK: - Pro Upgrade View (Using StoreView)
struct ProUpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = Store()
    
    var body: some View {
        NavigationView {
            StoreView()
                .environmentObject(store)
                .navigationTitle("Pro Upgrade")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Close") {
                            dismiss()
                        }
                    }
                }
        }
    }
}



#Preview {
    ContentView()
}
