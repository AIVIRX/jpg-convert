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
        case .pdf:
            return try await convertToPDF(image)
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
        
        print("Converting to PNG - Image size: \(image.size), scale: \(image.scale)")
        
        guard let pngData = image.pngData() else {
            print("❌ Failed to create PNG data")
            throw ConversionError.failedToConvert
        }
        
        print("✅ PNG data created, size: \(pngData.count) bytes")
        await updateProgress(0.8)
        
        guard let convertedImage = UIImage(data: pngData) else {
            print("❌ Failed to create UIImage from PNG data")
            throw ConversionError.failedToConvert
        }
        
        print("✅ PNG conversion successful - Final size: \(convertedImage.size), scale: \(convertedImage.scale)")
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
    
    /// Convert image to PDF format
    func convertToPDF(_ image: UIImage) async throws -> UIImage {
        await updateProgress(0.4)
        
        let pdfData = try await createPDFFromImage(image)
        
        await updateProgress(0.8)
        
        // For PDF, we return a thumbnail representation
        let thumbnail = try await createThumbnailFromPDF(pdfData)
        
        await updateProgress(1.0)
        return thumbnail
    }
    
    /// Convert multiple images to a single multi-page PDF
    func convertToMultiPagePDF(_ images: [UIImage]) async throws -> Data {
        await updateProgress(0.2)
        
        let pdfData = NSMutableData()
        let pdfConsumer = CGDataConsumer(data: pdfData as CFMutableData)!
        
        // Use a standard page size (A4) for consistency
        let pageSize = CGSize(width: 595.2, height: 841.8) // A4 in points (72 DPI)
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        
        guard let pdfContext = CGContext(consumer: pdfConsumer, mediaBox: &mediaBox, nil) else {
            throw ConversionError.failedToConvert
        }
        
        print("Creating multi-page PDF with \(images.count) images")
        
        for (index, image) in images.enumerated() {
            print("Adding page \(index + 1) for image \(index + 1)")
            
            pdfContext.beginPage(mediaBox: &mediaBox)
            
            // Calculate image positioning to fit within page bounds
            let imageSize = image.size
            let scale = min(pageSize.width / imageSize.width, pageSize.height / imageSize.height)
            let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            
            // Center the image on the page
            let x = (pageSize.width - scaledSize.width) / 2
            let y = (pageSize.height - scaledSize.height) / 2
            let imageRect = CGRect(origin: CGPoint(x: x, y: y), size: scaledSize)
            
            // Draw white background
            pdfContext.setFillColor(UIColor.white.cgColor)
            pdfContext.fill(mediaBox)
            
            // Draw the image
            if let cgImage = image.cgImage {
                pdfContext.draw(cgImage, in: imageRect)
            }
            
            pdfContext.endPage()
            
            // Update progress
            let progress = 0.2 + (0.6 * Float(index + 1) / Float(images.count))
            await updateProgress(progress)
        }
        
        pdfContext.closePDF()
        
        print("Multi-page PDF created successfully with \(images.count) pages")
        await updateProgress(1.0)
        return pdfData as Data
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
        
        print("=== Starting Batch Conversion ===")
        print("Format: \(format.displayName), Quality: \(quality)")
        print("Total images to convert: \(totalImages)")
        
        // Special handling for PDF: create a single multi-page PDF
        if format == .pdf && totalImages > 1 {
            print("📄 Creating multi-page PDF with \(totalImages) images")
            
            do {
                let imageArray = images.map { $0.originalImage }
                let pdfData = try await convertToMultiPagePDF(imageArray)
                
                // Create a single result representing the multi-page PDF
                let thumbnail = try await createThumbnailFromPDF(pdfData)
                
                // Update the first image model to represent the multi-page PDF
                var firstModel = images[0]
                firstModel.convertedImage = thumbnail
                firstModel.convertedFormat = format
                firstModel.compressionQuality = quality
                firstModel.pdfData = pdfData  // Store the actual PDF data
                firstModel.errorMessage = nil
                
                // Add a note that this is a multi-page PDF
                firstModel.errorMessage = "Multi-page PDF with \(totalImages) images"
                
                convertedImages.append(firstModel)
                
                print("✅ Multi-page PDF created successfully with \(totalImages) pages")
                
            } catch {
                print("❌ Multi-page PDF creation failed: \(error.localizedDescription)")
                // Mark all images as failed
                for imageModel in images {
                    var errorModel = imageModel
                    errorModel.errorMessage = "PDF creation failed: \(error.localizedDescription)"
                    convertedImages.append(errorModel)
                }
            }
            
        } else {
            // Normal conversion for other formats or single PDF
            for (index, imageModel) in images.enumerated() {
                print("--- Converting image \(index + 1)/\(totalImages) ---")
                print("Original format: \(imageModel.originalFormat.displayName)")
                print("Image size: \(imageModel.originalImage.size)")
                
                do {
                    let convertedImage = try await convertImage(imageModel.originalImage, to: format, quality: quality)
                    var updatedModel = imageModel
                    updatedModel.convertedImage = convertedImage
                    updatedModel.convertedFormat = format
                    updatedModel.compressionQuality = quality
                    convertedImages.append(updatedModel)
                    
                    print("✅ Image \(index + 1) converted successfully")
                    
                    // Update overall progress
                    let progress = Float(index + 1) / Float(totalImages)
                    await updateProgress(progress)
                    
                } catch {
                    print("❌ Image \(index + 1) failed: \(error.localizedDescription)")
                    var errorModel = imageModel
                    errorModel.errorMessage = error.localizedDescription
                    convertedImages.append(errorModel)
                }
            }
        }
        
        print("=== Batch Conversion Summary ===")
        print("Total processed: \(convertedImages.count)")
        print("Successful: \(convertedImages.filter { $0.convertedImage != nil }.count)")
        print("Failed: \(convertedImages.filter { $0.errorMessage != nil }.count)")
        
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
    
    private func createPDFFromImage(_ image: UIImage) async throws -> Data {
        let pdfData = NSMutableData()
        let pdfConsumer = CGDataConsumer(data: pdfData as CFMutableData)!
        
        var mediaBox = CGRect(origin: .zero, size: image.size)
        
        guard let pdfContext = CGContext(consumer: pdfConsumer, mediaBox: &mediaBox, nil) else {
            throw ConversionError.failedToConvert
        }
        
        pdfContext.beginPage(mediaBox: &mediaBox)
        
        if let cgImage = image.cgImage {
            pdfContext.draw(cgImage, in: mediaBox)
        }
        
        pdfContext.endPage()
        pdfContext.closePDF()
        
        return pdfData as Data
    }
    
    private func createThumbnailFromPDF(_ pdfData: Data) async throws -> UIImage {
        guard let provider = CGDataProvider(data: pdfData as CFData),
              let document = CGPDFDocument(provider) else {
            throw ConversionError.failedToConvert
        }
        
        guard let page = document.page(at: 1) else {
            throw ConversionError.failedToConvert
        }
        
        let pageRect = page.getBoxRect(.mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        
        let thumbnail = renderer.image { context in
            UIColor.white.setFill()
            context.fill(pageRect)
            
            context.cgContext.translateBy(x: 0, y: pageRect.height)
            context.cgContext.scaleBy(x: 1, y: -1)
            
            context.cgContext.drawPDFPage(page)
        }
        
        return thumbnail
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
