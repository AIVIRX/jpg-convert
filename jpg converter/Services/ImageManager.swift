//
//  ImageManager.swift
//  jpg converter
//
//  Created by Maicol Cabreja on 8/31/25.
//

import Foundation
import UIKit
import Photos
import UniformTypeIdentifiers
import ImageIO
import AVFoundation

// MARK: - Image Manager Service
class ImageManager: ObservableObject {
    
    // MARK: - Properties
    @Published var selectedImages: [ImageConversionModel] = []
    @Published var hasPhotoLibraryAccess = false
    @Published var errorMessage: String?
    
    private let converterService = ImageConverterService()
    
    // MARK: - Initialization
    init() {
        checkPhotoLibraryAccess()
    }
    
    // MARK: - Photo Library Access
    private func checkPhotoLibraryAccess() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        DispatchQueue.main.async {
            self.hasPhotoLibraryAccess = status == .authorized || status == .limited
        }
    }
    
    func requestPhotoLibraryAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await MainActor.run {
            self.hasPhotoLibraryAccess = status == .authorized || status == .limited
        }
        return hasPhotoLibraryAccess
    }
    
    // MARK: - Image Selection
    
    /// Add images from Photos picker
    func addImagesFromPhotos(_ images: [UIImage]) {
        for image in images {
            // Images are already orientation-corrected when loaded from Photos picker
            // Detect the actual format of the image
            let detectedFormat = detectImageFormat(from: image)
            let imageModel = ImageConversionModel(
                originalImage: image,
                originalFormat: detectedFormat,
                compressionQuality: 0.8
            )
            selectedImages.append(imageModel)
        }
    }
    
    
    /// Remove image at specific index
    func removeImage(at index: Int) {
        guard index >= 0 && index < selectedImages.count else { return }
        selectedImages.remove(at: index)
    }
    
    /// Clear all selected images
    func clearAllImages() {
        selectedImages.removeAll()
    }
    
    // MARK: - Image Format Detection
    
    private func detectImageFormat(from image: UIImage) -> ConversionFormat {
        // Try to detect format from image data
        if let cgImage = image.cgImage {
            // Check color space and alpha channel to make educated guesses
            let hasAlpha = cgImage.alphaInfo != .none && cgImage.alphaInfo != .noneSkipLast
            
            // Check if it's likely a PNG (has alpha channel)
            if hasAlpha {
                return .png
            }
            
            // Check color space for HEIC/HDR
            if let colorSpace = cgImage.colorSpace {
                let colorSpaceName = colorSpace.name
                if colorSpaceName == CGColorSpace.extendedLinearSRGB || 
                   colorSpaceName == CGColorSpace.extendedSRGB {
                    return .heic
                }
            }
            
            // Default to JPG for most other cases
            return .jpg
        }
        
        // Fallback to JPG if we can't determine
        return .jpg
    }
    
    private func detectImageFormat(from url: URL) -> ConversionFormat {
        let pathExtension = url.pathExtension.lowercased()
        
        switch pathExtension {
        case "jpg", "jpeg":
            return .jpg
        case "png":
            return .png
        case "heic", "heif":
            return .heic

        case "tiff", "tif":
            return .tiff
        default:
            return .jpg
        }
    }
    
    // MARK: - Image Orientation Fix
    
    /// Fix image orientation by drawing it in the correct orientation
    private func fixImageOrientation(_ image: UIImage) -> UIImage {
        // If the image is already in the correct orientation, return it as is
        if image.imageOrientation == .up {
            return image
        }

        // Create a new CGImage with the correct orientation
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        
        // Apply the correct transform based on orientation
        let context = UIGraphicsGetCurrentContext()
        context?.saveGState()
        
        // Move the origin to the center of the image
        context?.translateBy(x: image.size.width / 2, y: image.size.height / 2)
        
        // Apply the appropriate rotation
        switch image.imageOrientation {
        case .down:
            context?.rotate(by: .pi)
        case .left:
            context?.rotate(by: .pi / 2)
        case .right:
            context?.rotate(by: -.pi / 2)
        case .upMirrored:
            context?.scaleBy(x: -1, y: 1)
        case .downMirrored:
            context?.scaleBy(x: -1, y: 1)
            context?.rotate(by: .pi)
        case .leftMirrored:
            context?.scaleBy(x: -1, y: 1)
            context?.rotate(by: .pi / 2)
        case .rightMirrored:
            context?.scaleBy(x: -1, y: 1)
            context?.rotate(by: -.pi / 2)
        default:
            break
        }
        
        // Draw the image centered
        let rect = CGRect(x: -image.size.width / 2, y: -image.size.height / 2, width: image.size.width, height: image.size.height)
        image.draw(in: rect)
        
        context?.restoreGState()
        
        let correctedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return correctedImage ?? image
    }
    
    // MARK: - Image Export
    
    /// Export converted image to Photos
    func exportToPhotos(_ image: UIImage, format: ConversionFormat) async throws {
        // First check current permission status
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        if currentStatus == .notDetermined {
            // Request permission if not determined
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            await MainActor.run {
                self.hasPhotoLibraryAccess = newStatus == .authorized || newStatus == .limited
            }
            
            if newStatus != .authorized && newStatus != .limited {
                throw ExportError.noPhotoLibraryAccess
            }
        } else if currentStatus != .authorized && currentStatus != .limited {
            // Permission denied or restricted
            throw ExportError.noPhotoLibraryAccess
        }
        
        let data = try await getImageData(image, format: format)
        
        try await saveImageToPhotos(data)
    }
    
    /// Save image data to Photos
    private func saveImageToPhotos(_ data: Data) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: data, options: nil)
        }
    }
    

    

    
    /// Get image data for specified format
    private func getImageData(_ image: UIImage, format: ConversionFormat) async throws -> Data {
        // Ensure the image has correct orientation before exporting
        let correctedImage = fixImageOrientation(image)
        
        switch format {
        case .jpg:
            guard let data = correctedImage.jpegData(compressionQuality: 0.8) else {
                throw ExportError.failedToGetImageData
            }
            return data
        case .png:
            guard let data = correctedImage.pngData() else {
                throw ExportError.failedToGetImageData
            }
            return data
        case .heic:
            guard let data = try await converterService.convertImage(correctedImage, to: .heic, quality: 0.8).heicData() else {
                throw ExportError.failedToGetImageData
            }
            return data

        case .tiff:
            guard let cgImage = correctedImage.cgImage else {
                throw ExportError.failedToGetImageData
            }
            let data = NSMutableData()
            let destination = CGImageDestinationCreateWithData(data as CFMutableData, UTType.tiff.identifier as CFString, 1, nil)
            CGImageDestinationAddImage(destination!, cgImage, nil)
            CGImageDestinationFinalize(destination!)
            return data as Data
        }
    }
    

    
    /// Share image using UIActivityViewController
    func shareImage(_ image: UIImage, format: ConversionFormat) async throws -> [Any] {
        let data = try await getImageData(image, format: format)
        let fileName = "converted_image.\(format.fileExtension)"
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: tempURL)
        
        return [tempURL]
    }
    
    // MARK: - Batch Operations
    
    /// Export all converted images
    func exportAllImages() async throws {
        for imageModel in selectedImages {
            guard let convertedImage = imageModel.convertedImage,
                  let convertedFormat = imageModel.convertedFormat else { continue }
            
            try await exportToPhotos(convertedImage, format: convertedFormat)
        }
    }
    
    /// Get all converted images for sharing
    func getAllConvertedImagesForSharing() async throws -> [Any] {
        var shareItems: [Any] = []
        
        for imageModel in selectedImages {
            guard let convertedImage = imageModel.convertedImage,
                  let convertedFormat = imageModel.convertedFormat else { continue }
            
            let shareItem = try await shareImage(convertedImage, format: convertedFormat)
            shareItems.append(contentsOf: shareItem)
        }
        
        return shareItems
    }
}

// MARK: - Export Errors
enum ExportError: LocalizedError {
    case noPhotoLibraryAccess
    case failedToGetImageData
    case failedToSave
    case permissionDenied

    
    var errorDescription: String? {
        switch self {
        case .noPhotoLibraryAccess:
            return "Photo Library access is required to save images"
        case .failedToGetImageData:
            return "Failed to prepare image data for export"
        case .failedToSave:
            return "Failed to save image"
        case .permissionDenied:
            return "Photo Library access was denied"

        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noPhotoLibraryAccess:
            return "The app will request permission when you try to save"
        case .failedToGetImageData:
            return "Try converting the image again"
        case .failedToSave:
            return "Try converting the image again"
        case .permissionDenied:
            return "Go to Settings > Privacy & Security > Photos and enable access for JPG Converter"

        }
    }
}

// MARK: - UIImage Extension for HEIC
extension UIImage {
    func heicData() -> Data? {
        guard let cgImage = cgImage else { return nil }
        
        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext()
        
        // For HEIC, we'll use the default quality since compressionQuality option doesn't exist
        return context.heifRepresentation(of: ciImage, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
    }
}
