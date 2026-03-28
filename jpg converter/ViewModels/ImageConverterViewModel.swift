//
//  ImageConverterViewModel.swift
//  jpg converter
//
//  Created by Maicol Cabreja on 8/31/25.
//

import Foundation
import UIKit
import SwiftUI
import Combine
import PhotosUI

// MARK: - Image Converter View Model
@MainActor
class ImageConverterViewModel: ObservableObject {
    private static let interstitialFrequency = 2
    
    // MARK: - Published Properties
    @Published var selectedImages: [ImageConversionModel] = []
    @Published var selectedForExport: Set<UUID> = []
    @Published var targetFormat: ConversionFormat = .jpg
    @Published var compressionQuality: Float = 0.8
    @Published var isConverting = false
    @Published var conversionProgress: Float = 0.0
    @Published var isExporting = false
    @Published var exportProgress: Float = 0.0
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var showSuccess = false
    @Published var successMessage = ""
    @Published var shouldShowInterstitial = false
    
    // MARK: - Services
    private let converterService = ImageConverterService()
    private let imageManager = ImageManager()
    private var conversionGeneration = UUID()
    @AppStorage("successfulConversionCount") private var successfulConversionCount = 0
    
    // MARK: - Store Reference
    var store: Store?
    
    
    
    // MARK: - Initialization
    init() {
        setupBindings()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Bind to converter service
        converterService.$isConverting
            .assign(to: &$isConverting)
        
        converterService.$conversionProgress
            .assign(to: &$conversionProgress)
    }
    
    // MARK: - Image Selection
    
    /// Add images from Photos picker
    func addImagesFromPhotos(_ images: [UIImage]) {
        imageManager.addImagesFromPhotos(images)
        selectedImages = imageManager.selectedImages
    }
    
    
    /// Remove image at specific index
    func removeImage(at index: Int) {
        imageManager.removeImage(at: index)
        selectedImages = imageManager.selectedImages
    }

    /// Remove image by model id
    func removeImage(id: UUID) {
        guard let index = selectedImages.firstIndex(where: { $0.id == id }) else { return }
        removeImage(at: index)
    }
    
    /// Clear all selected images
    func clearAllImages() {
        // Invalidate any in-flight conversion result assignment.
        conversionGeneration = UUID()
        selectedImages.removeAll()
        imageManager.clearAllImages()
        selectedForExport.removeAll()
        shouldShowInterstitial = false
    }
    
    // MARK: - Export Selection Management
    
    /// Toggle selection of an image for export
    func toggleImageSelection(_ imageId: UUID) {
        if selectedForExport.contains(imageId) {
            selectedForExport.remove(imageId)
        } else {
            selectedForExport.insert(imageId)
        }
    }
    
    /// Select all converted images for export
    func selectAllConvertedImages() {
        selectedForExport = Set(selectedImages.compactMap { $0.convertedImage != nil ? $0.id : nil })
    }
    
    /// Clear all export selections
    func clearExportSelections() {
        selectedForExport.removeAll()
    }
    
    // MARK: - Target Format
    
    /// Set target format for conversion
    func setTargetFormat(_ format: ConversionFormat) {
        targetFormat = format
    }
    
    // MARK: - Compression Quality
    
    /// Update compression quality
    func updateCompressionQuality(_ quality: Float) {
        compressionQuality = quality
    }
    
    // MARK: - Image Conversion
    
    /// Convert selected images
    func convertImages() async {
        conversionGeneration = UUID()
        let generationAtStart = conversionGeneration

        guard !selectedImages.isEmpty else {
            showError(message: "Please select at least one JPG image to convert")
            return
        }
        
        isConverting = true
        conversionProgress = 0.0
        
        do {
            // Start progress monitoring
            let progressTask = Task {
                while !Task.isCancelled && isConverting {
                    conversionProgress = converterService.conversionProgress
                    try await Task.sleep(nanoseconds: 50_000_000) // 50ms
                }
            }
            
            let convertedImages = try await converterService.batchConvert(
                selectedImages,
                to: targetFormat,
                quality: compressionQuality
            )

            // If user cleared or restarted work while conversion was running,
            // ignore this stale result and do not repopulate UI.
            guard generationAtStart == conversionGeneration else {
                isConverting = false
                return
            }
            
            // Cancel progress monitoring
            progressTask.cancel()

            selectedImages = convertedImages
            imageManager.selectedImages = convertedImages
            
            // Check if any conversions actually failed
            let successfulConversions = convertedImages.filter { $0.convertedImage != nil }
            let failedConversions = convertedImages.filter { $0.errorMessage != nil }

            if failedConversions.isEmpty {
                // All conversions succeeded
                let formatName = targetFormat.displayName
                let count = successfulConversions.count
                showSuccess(message: "Successfully converted \(count) JPG image\(count == 1 ? "" : "s") to \(formatName)")
                
                // Show interstitial ad after successful conversion (only for non-premium users)
                if !(store?.isPremium ?? false) {
                    successfulConversionCount += 1
                    shouldShowInterstitial = successfulConversionCount.isMultiple(of: Self.interstitialFrequency)
                }
            } else if successfulConversions.isEmpty {
                // All conversions failed
                showError(message: "All conversions failed. Please try again.")
            } else {
                // Some succeeded, some failed
                let formatName = targetFormat.displayName
                showError(message: "\(successfulConversions.count) of \(convertedImages.count) images converted successfully to \(formatName). \(failedConversions.count) failed.")
            }
            
        } catch {
            showError(message: "Conversion failed: \(error.localizedDescription)")
        }
        
        isConverting = false
    }
    
    /// Convert single image
    func convertSingleImage(_ imageModel: ImageConversionModel) async {
        guard let index = selectedImages.firstIndex(where: { $0.id == imageModel.id }) else { return }
        
        selectedImages[index].isProcessing = true
        imageManager.selectedImages = selectedImages
        
        do {
            let convertedImage = try await converterService.convertImage(
                imageModel.originalImage,
                to: targetFormat,
                quality: compressionQuality
            )
            
            guard index < selectedImages.count else { return }
            selectedImages[index].convertedImage = convertedImage
            selectedImages[index].convertedFormat = targetFormat
            selectedImages[index].compressionQuality = compressionQuality
            selectedImages[index].isProcessing = false
            imageManager.selectedImages = selectedImages
            
        } catch {
            guard index < selectedImages.count else { return }
            selectedImages[index].errorMessage = error.localizedDescription
            selectedImages[index].isProcessing = false
            imageManager.selectedImages = selectedImages
        }
    }
    
    // MARK: - Export
    
    /// Export converted image to Photos
    func exportToPhotos(_ image: UIImage, format: ConversionFormat) async {
        await MainActor.run {
            isExporting = true
            exportProgress = 0.0
        }
        
        do {
            try await imageManager.exportToPhotos(image, format: format)
            await MainActor.run {
                exportProgress = 1.0
            }
            showSuccess(message: "Image saved to Photos")
        } catch let error as ExportError {
            var message = "Failed to save to Photos: \(error.localizedDescription)"
            if let suggestion = error.recoverySuggestion {
                message += "\n\n💡 Tip: \(suggestion)"
            }
            showError(message: message)
        } catch {
            showError(message: "Failed to save to Photos: \(error.localizedDescription)")
        }
        
        await MainActor.run {
            isExporting = false
            exportProgress = 0.0
        }
    }
    

    
    /// Share converted image
    func shareImage(_ image: UIImage, format: ConversionFormat) async -> [Any] {
        do {
            return try await imageManager.shareImage(image, format: format)
        } catch {
            showError(message: "Failed to prepare image for sharing: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Export all converted images
    func exportAllImages() async {
        await MainActor.run {
            isExporting = true
            exportProgress = 0.0
        }
        
        var successCount = 0
        var errorCount = 0
        
        for (index, imageModel) in selectedImages.enumerated() {
            if let convertedImage = imageModel.convertedImage,
               let convertedFormat = imageModel.convertedFormat {
                do {
                    try await imageManager.exportToPhotos(convertedImage, format: convertedFormat)
                    successCount += 1
                } catch {
                    errorCount += 1
                }
            }
            
            // Update progress
            await MainActor.run {
                exportProgress = Float(index + 1) / Float(selectedImages.count)
            }
        }
        
        await MainActor.run {
            isExporting = false
            exportProgress = 0.0
        }
        
        if errorCount == 0 {
            showSuccess(message: "All \(successCount) images exported successfully")
        } else if successCount > 0 {
            showError(message: "\(successCount) images exported successfully, \(errorCount) failed")
        } else {
            showError(message: "Failed to export all images")
        }
    }
    
    /// Get all converted images for sharing
    func getAllConvertedImagesForSharing() async -> [Any] {
        do {
            return try await imageManager.getAllConvertedImagesForSharing()
        } catch {
            showError(message: "Failed to prepare images for sharing: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Error and Success Handling
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
    
    private func showSuccess(message: String) {
        successMessage = message
        showSuccess = true
    }
}
