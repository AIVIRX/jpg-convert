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

struct ContentView: View {
    @StateObject private var viewModel = ImageConverterViewModel()
    @State private var showFilesPicker = false
    @State private var showResults = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    
    var body: some View {
        NavigationStack{
            VStack(spacing: 0) {
                // Main Content
                                ScrollView {
                    VStack(spacing: 24) {
                        // Image Selection Area (First)
                        imageSelectionView
                        
                        // Selected Images Grid
                        if !viewModel.selectedImages.isEmpty {
                            selectedImagesView
                        }
                        
                        // Target Format Selection (After images are selected)
                        if !viewModel.selectedImages.isEmpty {
                            targetFormatSelectionView
                        }
                        
                        // Conversion Controls
                        if !viewModel.selectedImages.isEmpty {
                            conversionControlsView
                        }
                        
                        // Results Section (after conversion)
                        if !viewModel.selectedImages.isEmpty && viewModel.selectedImages.contains(where: { $0.convertedImage != nil }) {
                            resultsSectionView
                        }
                        
                        // Pro Upgrade Banner
                        if !viewModel.isProUser {
                            proUpgradeBanner
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100) // Space for bottom sheet
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $viewModel.showProUpgrade, onDismiss: {
            // Reset showResults when Pro sheet is dismissed to prevent unwanted results display
            showResults = false
        }) {
            ProUpgradeView()
        }
        .onChange(of: selectedPhotos) { oldValue, newValue in
            Task {
                await loadPhotosFromPicker(newValue)
            }
        }
        .sheet(isPresented: $showFilesPicker) {
            FilesPickerView(isPresented: $showFilesPicker) { urls in
                viewModel.addImagesFromFiles(urls)
            }
        }
        .sheet(isPresented: $showResults) {
            ConversionResultsView(isPresented: $showResults, viewModel: viewModel)
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
    
    // MARK: - Results Section View
    private var resultsSectionView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("JPG → \(viewModel.targetFormat.displayName) Results")
                    .font(.headline)
                    .foregroundColor(.green)
                
                Spacer()
                
                Button("View Full Results") {
                    showResults = true
                }
                .font(.subheadline)
                .foregroundColor(.accentColor)
            }
            
            // Show converted images with download options
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                ForEach(viewModel.selectedImages.filter { $0.convertedImage != nil }) { imageModel in
                    ConvertedImageResultView(imageModel: imageModel, viewModel: viewModel)
                }
            }
            
            // Selection info and bulk action buttons
            let convertedCount = viewModel.selectedImages.filter({ $0.convertedImage != nil }).count
            if convertedCount > 1 {
                selectionInfo
                bulkActionButtons
            }
        }
    }
    
    // MARK: - Selection Info
    private var selectionInfo: some View {
        HStack {
            Text("Multiple images converted")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button("Select All") {
                viewModel.selectAllConvertedImages()
            }
            .font(.caption)
            .foregroundColor(.accentColor)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Bulk Action Buttons
    private var bulkActionButtons: some View {
        VStack(spacing: 12) {
            Text("Bulk Actions")
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                // Bulk save button
                Button(action: {
                    Task {
                        // Export only selected images
                        for imageModel in viewModel.selectedImages {
                            if viewModel.selectedForExport.contains(imageModel.id),
                               let convertedImage = imageModel.convertedImage,
                               let convertedFormat = imageModel.convertedFormat {
                                if convertedFormat == .pdf {
                                    await viewModel.exportToFiles(convertedImage, format: convertedFormat, imageModel: imageModel)
                                } else {
                                    await viewModel.exportToPhotos(convertedImage, format: convertedFormat)
                                }
                            }
                        }
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
                
                // Bulk share button
                Button(action: {
                    Task {
                        // Share only selected images
                        var shareItems: [Any] = []
                        for imageModel in viewModel.selectedImages {
                            if viewModel.selectedForExport.contains(imageModel.id),
                               let convertedImage = imageModel.convertedImage,
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
    
    // MARK: - Helper Methods
    
    private func loadPhotosFromPicker(_ items: [PhotosPickerItem]) async {
        var images: [UIImage] = []
        
        for item in items {
            if let transferableImage = try? await item.loadTransferable(type: TransferableImage.self) {
                let image = transferableImage.uiImage
                print("=== Loading Image from Photos Picker ===")
                print("Image loaded successfully using TransferableImage")
                print("Original orientation: \(image.imageOrientation.rawValue)")
                print("Original size: \(image.size)")
                print("Original scale: \(image.scale)")
                
                // The TransferableImage preserves orientation, but we still need to normalize it
                // for consistent display across all image types (JPG, PNG, HEIC, HDR, etc.)
                print("=== Normalizing Image Orientation ===")
                
                // Check if this is an HDR image for logging purposes
                let isHDR = image.cgImage?.colorSpace?.name == CGColorSpace.extendedLinearSRGB || 
                            image.cgImage?.colorSpace?.name == CGColorSpace.extendedSRGB
                print("Is HDR image: \(isHDR)")
                
                // Apply the simple orientation normalization
                let correctedImage = fixImageOrientation(image)
                
                print("=== After Orientation Normalization ===")
                print("Final orientation: \(correctedImage.imageOrientation.rawValue)")
                print("Final size: \(correctedImage.size)")
                print("Final scale: \(correctedImage.scale)")
                print("=== End Image Loading ===\n")
                
                images.append(correctedImage)
            } else {
                print("Failed to load image using TransferableImage")
            }
        }
        
        await MainActor.run {
            viewModel.addImagesFromPhotos(images)
            // Clear the selection after adding images
            selectedPhotos.removeAll()
        }
    }
    
    /// Fix image orientation by drawing it into a new context in .up orientation
    /// This approach strips the EXIF orientation and gives you a pixel-correct image
    private func fixImageOrientation(_ image: UIImage) -> UIImage {
        // If the image is already in the correct orientation, return it as is
        guard image.imageOrientation != .up else {
            print("Image already in correct orientation (.up)")
            return image
        }
        
        print("Fixing image orientation from: \(image.imageOrientation.rawValue)")
        print("Image size: \(image.size), scale: \(image.scale)")
        
        // Create a new context and draw the image - CoreGraphics will normalize the orientation
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        if let corrected = normalizedImage {
            print("Successfully normalized image orientation")
            print("Corrected image size: \(corrected.size)")
            print("Corrected image scale: \(corrected.scale)")
            print("Corrected image orientation: \(corrected.imageOrientation.rawValue)")
            return corrected
        } else {
            print("Failed to normalize image, returning original")
            return image
        }
    }
    
    /// Alternative orientation fixing method using CIImage
    private func fixImageOrientationAlternative(_ image: UIImage) -> UIImage {
        print("=== Trying Alternative Orientation Fix ===")
        
        guard let cgImage = image.cgImage else {
            print("No CGImage available, returning original")
            return image
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext()
        
        // Create a new UIImage with the corrected orientation
        if let correctedCGImage = context.createCGImage(ciImage, from: ciImage.extent) {
            let correctedImage = UIImage(cgImage: correctedCGImage, scale: image.scale, orientation: .up)
            print("Alternative method successful")
            print("Corrected image size: \(correctedImage.size)")
            print("Corrected image scale: \(correctedImage.scale)")
            print("Corrected image orientation: \(correctedImage.imageOrientation.rawValue)")
            return correctedImage
        } else {
            print("Alternative method failed, returning original")
            return image
        }
    }
    
    /// Detect if an image appears to be upside down by analyzing pixel data
    private func isImageUpsideDown(_ image: UIImage) -> Bool {
        print("=== Analyzing Image for Upside-Down Detection ===")
        
        guard let cgImage = image.cgImage else {
            print("No CGImage available for analysis")
            return false
        }
        
        // Get image dimensions
        let width = cgImage.width
        let height = cgImage.height
        
        print("Image dimensions: \(width) x \(height)")
        print("Image orientation value: \(image.imageOrientation.rawValue)")
        
        // Let's try a different approach - check if the image is actually an HDR image
        // and if it has a specific orientation that commonly causes issues
        let isHDR = image.cgImage?.colorSpace?.name == CGColorSpace.extendedLinearSRGB || 
                    image.cgImage?.colorSpace?.name == CGColorSpace.extendedSRGB
        
        if isHDR {
            print("This is an HDR image - checking for common HDR orientation issues")
            
            // HDR images often have orientation 3 (left) or 6 (right) which can appear upside down
            // Let's be more aggressive with HDR images
            let hdrProblemOrientations = [1, 2, 3, 4, 5, 6, 7, 8] // All non-zero orientations
            let hasHDROrientationIssue = hdrProblemOrientations.contains(image.imageOrientation.rawValue)
            
            print("HDR image has orientation issue: \(hasHDROrientationIssue)")
            return hasHDROrientationIssue
        } else {
            // For non-HDR images, use the standard approach
            let potentiallyUpsideDown = [3, 6, 8]
            let isUpsideDown = potentiallyUpsideDown.contains(image.imageOrientation.rawValue)
            
            print("Non-HDR image potentially upside down: \(isUpsideDown)")
            return isUpsideDown
        }
    }
    
    /// Force create a new UIImage with correct orientation by completely recreating it
    private func forceCorrectOrientation(_ image: UIImage) -> UIImage {
        print("=== Force Correcting Image Orientation ===")
        
        guard let cgImage = image.cgImage else {
            print("No CGImage available for force correction")
            return image
        }
        
        // Get the current problematic orientation
        let currentOrientation = image.imageOrientation
        print("Current problematic orientation: \(currentOrientation.rawValue)")
        
        // Create a completely new UIImage with explicit .up orientation
        let newImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
        
        print("Created new image with forced .up orientation")
        print("New image orientation: \(newImage.imageOrientation.rawValue)")
        
        return newImage
    }
    
    /// HDR-specific orientation fixing method
    private func fixHDRImageOrientation(_ image: UIImage) -> UIImage {
        print("=== Trying HDR-Specific Orientation Fix ===")
        
        // HDR images sometimes need special handling
        // This method tries to completely recreate the image with proper orientation
        
        guard let cgImage = image.cgImage else {
            print("No CGImage available for HDR fix, returning original")
            return image
        }
        
        // Get the current orientation and size
        let currentOrientation = image.imageOrientation
        let size = image.size
        let scale = image.scale
        
        print("HDR image - Current orientation: \(currentOrientation.rawValue)")
        print("HDR image - Size: \(size), Scale: \(scale)")
        
        // Create a new graphics context
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        
        // For HDR images, we'll try to force the correct orientation
        // by applying the inverse transform and redrawing
        
        let context = UIGraphicsGetCurrentContext()
        context?.saveGState()
        
        // Move to center
        context?.translateBy(x: size.width / 2, y: size.height / 2)
        
        // Apply the inverse transform
        switch currentOrientation {
        case .down:
            context?.rotate(by: .pi)
        case .left:
            context?.rotate(by: -.pi / 2)
        case .right:
            context?.rotate(by: .pi / 2)
        case .upMirrored:
            context?.scaleBy(x: -1, y: 1)
        case .downMirrored:
            context?.scaleBy(x: -1, y: 1)
            context?.rotate(by: .pi)
        case .leftMirrored:
            context?.scaleBy(x: -1, y: 1)
            context?.rotate(by: -.pi / 2)
        case .rightMirrored:
            context?.scaleBy(x: -1, y: 1)
            context?.rotate(by: .pi / 2)
        default:
            break
        }
        
        // Draw the image
        let rect = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
        context?.draw(cgImage, in: rect)
        
        context?.restoreGState()
        
        let correctedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        if let corrected = correctedImage {
            print("HDR-specific fix successful")
            print("Final HDR image orientation: \(corrected.imageOrientation.rawValue)")
            return corrected
        } else {
            print("HDR-specific fix failed, returning original")
            return image
        }
    }
    
    /// Aggressive orientation fixing method for stubborn HDR images
    private func fixImageOrientationAggressive(_ image: UIImage) -> UIImage {
        print("=== Trying Aggressive Orientation Fix ===")
        
        // This method tries to force the image into the correct orientation
        // by completely recreating it with explicit transforms
        
        guard let cgImage = image.cgImage else {
            print("No CGImage available for aggressive fix, returning original")
            return image
        }
        
        // Get the current orientation
        let currentOrientation = image.imageOrientation
        print("Current orientation for aggressive fix: \(currentOrientation.rawValue)")
        
        // Create a new graphics context with the correct size
        let size = image.size
        UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
        
        // Apply the inverse transform to correct the orientation
        let context = UIGraphicsGetCurrentContext()
        context?.saveGState()
        
        // Move to center
        context?.translateBy(x: size.width / 2, y: size.height / 2)
        
        // Apply the inverse rotation based on current orientation
        switch currentOrientation {
        case .down:
            context?.rotate(by: .pi)
        case .left:
            context?.rotate(by: -.pi / 2)
        case .right:
            context?.rotate(by: .pi / 2)
        case .upMirrored:
            context?.scaleBy(x: -1, y: 1)
        case .downMirrored:
            context?.scaleBy(x: -1, y: 1)
            context?.rotate(by: .pi)
        case .leftMirrored:
            context?.scaleBy(x: -1, y: 1)
            context?.rotate(by: -.pi / 2)
        case .rightMirrored:
            context?.scaleBy(x: -1, y: 1)
            context?.rotate(by: .pi / 2)
        default:
            break
        }
        
        // Draw the image
        let rect = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
        context?.draw(cgImage, in: rect)
        
        context?.restoreGState()
        
        let correctedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        if let corrected = correctedImage {
            print("Aggressive fix successful")
            print("Final orientation: \(corrected.imageOrientation.rawValue)")
            return corrected
        } else {
            print("Aggressive fix failed, returning original")
            return image
        }
    }
    
    // MARK: - Target Format Selection View
    private var targetFormatSelectionView: some View {
        VStack(spacing: 16) {
            Text("Choose Output Format")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Select the format you want to convert your JPG images to")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Horizontal scrollable format selection
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ConversionDirection.fromJPG.targetFormats) { format in
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
    
    
    private var imageSelectionView: some View {
        VStack(spacing: 10) {
            Text("Select JPG Images")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Choose the JPG photos you want to convert")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 16) {
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 10,
                    matching: .images,
                    photoLibrary: .shared() // Ensures access to all photos including HDR
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
    
    // MARK: - Selected Images View
    private var selectedImagesView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Selected JPG Images (\(viewModel.selectedImages.count))")
                    .font(.headline)
                
                Spacer()
                
                Button("Clear All") {
                    viewModel.clearAllImages()
                }
                .foregroundColor(.red)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                ForEach(Array(viewModel.selectedImages.enumerated()), id: \.element.id) { index, imageModel in
                    SelectedImageView(
                        imageModel: imageModel,
                        onRemove: {
                            viewModel.removeImage(at: index)
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Conversion Controls View
    private var conversionControlsView: some View {
        VStack(spacing: 16) {
            // Compression Quality Slider (Pro feature)
            if viewModel.canUseCompressionSlider {
                compressionQualityView
            }
            
            // Convert Button
            Button(action: {
                Task {
                    await viewModel.convertImages()
                    // Only show results if conversion actually succeeded and Pro sheet wasn't shown
                    if !viewModel.showProUpgrade && !viewModel.selectedImages.isEmpty && viewModel.selectedImages.contains(where: { $0.convertedImage != nil }) {
                        showResults = true
                    }
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
            
            // Progress Bar
            if viewModel.isConverting {
                ProgressView(value: viewModel.conversionProgress)
                    .progressViewStyle(LinearProgressViewStyle())
            }
        }
    }
    

    
    // MARK: - Compression Quality View
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
    
    // MARK: - Pro Upgrade Banner
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
            
            Text("Unlock batch JPG conversion, quality control, and unlimited conversions")
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
        case .png: return "photo.fill"
        case .heic: return "photo.badge.plus"
        case .pdf: return "doc.text.fill"
        case .tiff: return "photo.artframe"
        default: return "photo"
        }
    }
}



// MARK: - Selected Image View
struct SelectedImageView: View {
    let imageModel: ImageConversionModel
    let onRemove: () -> Void
    
    var body: some View {
        ZStack {
            // Dark background card
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .frame(height: 120)
            
            // Remove button in top right
            VStack {
                HStack {
                    Spacer()
                    
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.black)
                            .background(Color.white)
                            .clipShape(Circle())
                    }
                }
                
                Spacer()
            }
            .padding(8)
            
            // Processing indicator (centered)
            if imageModel.isProcessing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .secondary))
                    .scaleEffect(1.2)
            }
            
            // Error indicator (centered)
            if imageModel.errorMessage != nil {
                VStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                    
                    Text("Error")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(height: 120)
    }
}

// MARK: - Converted Image Result View
struct ConvertedImageResultView: View {
    let imageModel: ImageConversionModel
    let viewModel: ImageConverterViewModel
    
    // Computed property for selection state
    private var isSelected: Bool {
        viewModel.selectedForExport.contains(imageModel.id)
    }
    
    // Auto-select if this is the only converted image
    private var shouldAutoSelect: Bool {
        let convertedCount = viewModel.selectedImages.filter { $0.convertedImage != nil }.count
        return convertedCount == 1
    }
    
    // Check if this image needs orientation correction (should be false now with proper normalization)
    private var needsOrientationFix: Bool {
        // With proper orientation normalization, this should always be false
        if let convertedImage = imageModel.convertedImage {
            let orientation = convertedImage.imageOrientation.rawValue
            let needsFix = orientation != 0
            if needsFix {
                print("WARNING: Image still has non-zero orientation after normalization: \(orientation)")
            }
            return needsFix
        }
        return false
    }
    

    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if let convertedImage = imageModel.convertedImage {
                    Image(uiImage: convertedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 100)
                        .clipped()
                        .cornerRadius(8)
                        .onAppear {
                            // Log the final orientation for debugging
                            print("Image displayed with orientation: \(convertedImage.imageOrientation.rawValue)")
                        }

                }
                
                // Selection indicator
                VStack {
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            viewModel.toggleImageSelection(imageModel.id)
                        }) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundColor(isSelected ? .accentColor : .secondary)
                                .background(Color.white)
                                .clipShape(Circle())
                        }
                    }
                    
                    Spacer()
                }
                .padding(8)
            }
            
            VStack(spacing: 4) {
                Text("\(imageModel.originalFormat.displayName) → \(imageModel.convertedFormat?.displayName ?? "")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Action buttons
                HStack(spacing: 8) {
                    // Save button (Photos for images, Files for PDFs)
                    Button(action: {
                        Task {
                            if let convertedImage = imageModel.convertedImage,
                               let convertedFormat = imageModel.convertedFormat {
                                if convertedFormat == .pdf {
                                    await viewModel.exportToFiles(convertedImage, format: convertedFormat, imageModel: imageModel)
                                } else {
                                    await viewModel.exportToPhotos(convertedImage, format: convertedFormat)
                                }
                            }
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: imageModel.convertedFormat == .pdf ? "folder" : "photo")
                            Text(imageModel.convertedFormat == .pdf ? "Files" : "Photos")
                        }
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                    
                    // Share button
                    Button(action: {
                        Task {
                            if let convertedImage = imageModel.convertedImage,
                               let convertedFormat = imageModel.convertedFormat {
                                let items = await viewModel.shareImage(convertedImage, format: convertedFormat)
                                let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
                                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                   let window = windowScene.windows.first {
                                    window.rootViewController?.present(activityVC, animated: true)
                                }
                            }
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share")
                        }
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                }
            }
        }
        .onAppear {
            // Auto-select if this is the only converted image
            if shouldAutoSelect {
                viewModel.toggleImageSelection(imageModel.id)
            }
        }
    }
}

// MARK: - Pro Upgrade View
struct ProUpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.yellow)
                    
                    Text("Upgrade to Pro")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Unlock all features and convert JPG images without limits")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Features
                VStack(spacing: 16) {
                    FeatureRow(icon: "photo.stack", title: "Batch JPG Conversion", description: "Convert multiple JPG images at once")
                    FeatureRow(icon: "slider.horizontal.3", title: "Quality Control", description: "Adjust compression and quality settings")
                    FeatureRow(icon: "infinity", title: "Unlimited Conversions", description: "No more waiting between conversions")
                    FeatureRow(icon: "icloud.and.arrow.up", title: "Cloud Export", description: "Save directly to iCloud and other services")
                }
                
                Spacer()
                
                // Upgrade Button
                Button(action: {
                    // StoreKit integration would go here
                }) {
                    Text("Upgrade Now - $4.99")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
                Button("Restore Purchases") {
                    // StoreKit restore would go here
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
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

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    ContentView()
}