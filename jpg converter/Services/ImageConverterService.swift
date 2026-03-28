//
//  ImageConverterService.swift
//  jpg converter
//
//  Created by Maicol Cabreja on 8/31/25.
//

import Foundation
import UIKit
import CoreGraphics
import ImageIO
import CoreImage
import UniformTypeIdentifiers

// MARK: - Image Converter Service
class ImageConverterService: ObservableObject {
    
    // MARK: - Properties
    @Published var isConverting = false
    @Published var conversionProgress: Float = 0.0
    
    // MARK: - Public Methods
    
    /// Convert image to specified format
    func convertImage(_ image: UIImage, to format: ConversionFormat, quality: Float = 0.8) async throws -> UIImage {
        await MainActor.run {
            isConverting = true
            conversionProgress = 0.0
        }
        
        defer {
            Task { @MainActor in
                isConverting = false
                conversionProgress = 0.0
            }
        }
        
        // Update progress
        await updateProgress(0.2)
        
        switch format {
        case .jpg:
            return try await convertToJPG(image, quality: quality)
        case .png:
            return try await convertToPNG(image)
        case .heic:
            return try await convertToHEIC(image, quality: quality)
        case .tiff:
            return try await convertToTIFF(image)
        }
    }
    
    /// Convert image to JPG format
    func convertToJPG(_ image: UIImage, quality: Float) async throws -> UIImage {
        await updateProgress(0.4)
        
        guard let jpegData = image.jpegData(compressionQuality: CGFloat(quality)) else {
            throw ConversionError.failedToConvert
        }
        
        await updateProgress(0.8)
        
        guard let convertedImage = UIImage(data: jpegData) else {
            throw ConversionError.failedToConvert
        }
        
        await updateProgress(1.0)
        return convertedImage
    }
    
    /// Convert image to PNG format
    func convertToPNG(_ image: UIImage) async throws -> UIImage {
        await updateProgress(0.4)

        guard let pngData = image.pngData() else {
            throw ConversionError.failedToConvert
        }

        await updateProgress(0.8)
        
        guard let convertedImage = UIImage(data: pngData) else {
            throw ConversionError.failedToConvert
        }

        await updateProgress(1.0)
        return convertedImage
    }
    
    /// Convert image to HEIC format
    func convertToHEIC(_ image: UIImage, quality: Float) async throws -> UIImage {
        await updateProgress(0.4)
        
        guard let heicData = try await convertToHEICData(image, quality: quality) else {
            throw ConversionError.failedToConvert
        }
        
        await updateProgress(0.8)
        
        guard let convertedImage = UIImage(data: heicData) else {
            throw ConversionError.failedToConvert
        }
        
        await updateProgress(1.0)
        return convertedImage
    }
    
    
    
    /// Convert image to TIFF format
    func convertToTIFF(_ image: UIImage) async throws -> UIImage {
        await updateProgress(0.4)
        
        guard let cgImage = image.cgImage else {
            throw ConversionError.failedToConvert
        }
        
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data as CFMutableData, UTType.tiff.identifier as CFString, 1, nil)
        CGImageDestinationAddImage(destination!, cgImage, nil)
        CGImageDestinationFinalize(destination!)
        
        await updateProgress(0.8)
        
        guard let convertedImage = UIImage(data: data as Data) else {
            throw ConversionError.failedToConvert
        }
        
        await updateProgress(1.0)
        return convertedImage
    }
    
    /// Batch convert multiple images
    func batchConvert(_ images: [ImageConversionModel], to format: ConversionFormat, quality: Float = 0.8) async throws -> [ImageConversionModel] {
        var convertedImages: [ImageConversionModel] = []
        let totalImages = images.count

        // Normal conversion for all formats
        for (index, imageModel) in images.enumerated() {
            do {
                let convertedImage = try await convertImage(imageModel.originalImage, to: format, quality: quality)
                var updatedModel = imageModel
                updatedModel.convertedImage = convertedImage
                updatedModel.convertedFormat = format
                updatedModel.compressionQuality = quality
                convertedImages.append(updatedModel)

                // Update overall progress
                let progress = Float(index + 1) / Float(totalImages)
                await updateProgress(progress)
            } catch {
                var errorModel = imageModel
                errorModel.errorMessage = error.localizedDescription
                convertedImages.append(errorModel)
            }
        }

        return convertedImages
    }
    
    // MARK: - Private Methods
    
    private func updateProgress(_ progress: Float) async {
        await MainActor.run {
            conversionProgress = progress
        }
    }
    
    private func convertToHEICData(_ image: UIImage, quality: Float) async throws -> Data? {
        guard let cgImage = image.cgImage else { return nil }
        
        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext()
        
        // For HEIC, we'll use the default quality since compressionQuality option doesn't exist
        return context.heifRepresentation(of: ciImage, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
    }
    
}

// MARK: - Conversion Errors
enum ConversionError: LocalizedError {
    case failedToConvert
    case unsupportedFormat
    case invalidImageData
    
    var errorDescription: String? {
        switch self {
        case .failedToConvert:
            return "Failed to convert image"
        case .unsupportedFormat:
            return "Unsupported image format"
        case .invalidImageData:
            return "Invalid image data"
        }
    }
}
