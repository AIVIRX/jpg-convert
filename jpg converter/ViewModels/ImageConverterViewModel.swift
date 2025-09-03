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
    
    // MARK: - Published Properties
    @Published var selectedImages: [ImageConversionModel] = []
    @Published var selectedForExport: Set<UUID> = []
    @Published var targetFormat: ConversionFormat = .jpg
    @Published var compressionQuality: Float = 0.8
    @Published var isConverting = false
    @Published var conversionProgress: Float = 0.0
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var showSuccess = false
    @Published var successMessage = ""
    
    // MARK: - Services
    private let converterService = ImageConverterService()
    private let imageManager = ImageManager()
    
    
    // MARK: - Initialization
    init() {
        setupBindings()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Bind to image manager
        imageManager.$selectedImages
            .assign(to: &$selectedImages)
        
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
    }
    
    /// Add images from Files picker
    func addImagesFromFiles(_ urls: [URL]) {
        imageManager.addImagesFromFiles(urls)
    }
    
    /// Remove image at specific index
    func removeImage(at index: Int) {
        imageManager.removeImage(at: index)
    }
    
    /// Clear all selected images
    func clearAllImages() {
        imageManager.clearAllImages()
        selectedForExport.removeAll()
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
        guard !selectedImages.isEmpty else {
            showError(message: "Please select at least one JPG image to convert")
            return
        }
        
        // Check if user can use batch conversion
        if selectedImages.count > 1 {
            // Premium feature restriction - this will be handled by the UI
            showError(message: "Batch conversion requires Premium. Please upgrade to unlock this feature.")
            return
        }
        
        isConverting = true
        conversionProgress = 0.0
        
        do {
            print("=== Starting Batch Conversion ===")
            print("Converting \(selectedImages.count) images to \(targetFormat.displayName)")
            print("Compression quality: \(compressionQuality)")
            
            let convertedImages = try await converterService.batchConvert(
                selectedImages,
                to: targetFormat,
                quality: compressionQuality
            )
            
            print("=== Batch Conversion Completed ===")
            print("Total images processed: \(convertedImages.count)")
            
            // Update the selected images with converted versions
            selectedImages = convertedImages
            
            // Check if any conversions actually failed
            let successfulConversions = convertedImages.filter { $0.convertedImage != nil }
            let failedConversions = convertedImages.filter { $0.errorMessage != nil }
            
            print("Successful conversions: \(successfulConversions.count)")
            print("Failed conversions: \(failedConversions.count)")
            
            if failedConversions.isEmpty {
                // All conversions succeeded
                let formatName = targetFormat.displayName
                let count = successfulConversions.count
                print("✅ All conversions succeeded!")
                showSuccess(message: "Successfully converted \(count) JPG image\(count == 1 ? "" : "s") to \(formatName)")
            } else if successfulConversions.isEmpty {
                // All conversions failed
                print("❌ All conversions failed!")
                showError(message: "All conversions failed. Please try again.")
            } else {
                // Some succeeded, some failed
                let formatName = targetFormat.displayName
                print("⚠️ Mixed results: \(successfulConversions.count) succeeded, \(failedConversions.count) failed")
                showError(message: "\(successfulConversions.count) of \(convertedImages.count) images converted successfully to \(formatName). \(failedConversions.count) failed.")
            }
            
        } catch {
            print("❌ Conversion error: \(error.localizedDescription)")
            showError(message: "Conversion failed: \(error.localizedDescription)")
        }
        
        isConverting = false
    }
    
    /// Convert single image
    func convertSingleImage(_ imageModel: ImageConversionModel) async {
        guard let index = selectedImages.firstIndex(where: { $0.id == imageModel.id }) else { return }
        
        selectedImages[index].isProcessing = true
        
        do {
            let convertedImage = try await converterService.convertImage(
                imageModel.originalImage,
                to: targetFormat,
                quality: compressionQuality
            )
            
            selectedImages[index].convertedImage = convertedImage
            selectedImages[index].convertedFormat = targetFormat
            selectedImages[index].compressionQuality = compressionQuality
            selectedImages[index].isProcessing = false
            
        } catch {
            selectedImages[index].errorMessage = error.localizedDescription
            selectedImages[index].isProcessing = false
        }
    }
    
    // MARK: - Export
    
    /// Export converted image to Photos
    func exportToPhotos(_ image: UIImage, format: ConversionFormat) async {
        do {
            try await imageManager.exportToPhotos(image, format: format)
            
            // Show different success messages based on format
            if format == .pdf {
                showSuccess(message: "PDF saved to Photos (may not display properly)")
            } else {
                showSuccess(message: "Image saved to Photos")
            }
        } catch let error as ExportError {
            var message = "Failed to save to Photos: \(error.localizedDescription)"
            if let suggestion = error.recoverySuggestion {
                message += "\n\n💡 Tip: \(suggestion)"
            }
            
            // Add specific guidance for PDFs
            if format == .pdf {
                message += "\n\n📱 PDFs work best when saved to Files or shared via other apps"
            }
            
            showError(message: message)
        } catch {
            showError(message: "Failed to save to Photos: \(error.localizedDescription)")
        }
    }
    
    /// Export converted image to Files
    func exportToFiles(_ image: UIImage, format: ConversionFormat, imageModel: ImageConversionModel? = nil) async {
        do {
            // For multi-page PDFs, use the stored PDF data if available
            if format == .pdf, let imageModel = imageModel, let pdfData = imageModel.pdfData {
                _ = try await imageManager.exportPDFDataToFiles(pdfData)
                showSuccess(message: "Multi-page PDF saved to Files")
            } else {
                _ = try await imageManager.exportToFiles(image, format: format)
                
                // Show different success messages based on format
                if format == .pdf {
                    showSuccess(message: "PDF saved to Files successfully")
                } else {
                    showSuccess(message: "Image saved to Files")
                }
            }
        } catch {
            showError(message: "Failed to save to Files: \(error.localizedDescription)")
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
        do {
            try await imageManager.exportAllImages()
            showSuccess(message: "All images exported successfully")
        } catch {
            showError(message: "Failed to export images: \(error.localizedDescription)")
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
