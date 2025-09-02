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
            let imageModel = ImageConversionModel(
                originalImage: image,
                originalFormat: .jpg,
                compressionQuality: 0.8
            )
            selectedImages.append(imageModel)
        }
    }
    
    /// Add images from Files picker
    func addImagesFromFiles(_ urls: [URL]) {
        for url in urls {
            if let image = UIImage(contentsOfFile: url.path) {
                // Check if the file is actually a JPG
                let format = detectImageFormat(from: url)
                if format == .jpg {
                    print("Loaded JPG from Files - Original orientation: \(image.imageOrientation.rawValue)")
                    // Fix image orientation before adding
                    let correctedImage = fixImageOrientation(image)
                    let imageModel = ImageConversionModel(
                        originalImage: correctedImage,
                        originalFormat: .jpg,
                        compressionQuality: 0.8
                    )
                    selectedImages.append(imageModel)
                } else {
                    // Could show an alert that only JPG files are supported
                    print("Skipping non-JPG file: \(url.lastPathComponent)")
                }
            }
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
        // Default to JPG if we can't determine format
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
        case "pdf":
            return .pdf
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
        
        print("Fixing image orientation from: \(image.imageOrientation.rawValue)")
        
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
        
        if correctedImage != nil {
            print("Successfully fixed image orientation")
        } else {
            print("Failed to fix image orientation, using original")
        }
        
        
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
        
        // For PDFs, we need to handle them differently
        if format == .pdf {
            try await savePDFToPhotos(data)
        } else {
            try await saveImageToPhotos(data)
        }
    }
    
    /// Save image data to Photos
    private func saveImageToPhotos(_ data: Data) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: data, options: nil)
        }
    }
    
    /// Save PDF data to Photos (as a document)
    private func savePDFToPhotos(_ data: Data) async throws {
        // Create a temporary file for the PDF
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("converted_document.pdf")
        try data.write(to: tempURL)
        
        // For PDFs, we'll try to save it as a photo asset first
        // Note: iOS Photos app doesn't handle PDFs well, so this may not work consistently
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: nil)
            }
            
            // If we get here, it was saved successfully
            // However, the user may not see it properly in Photos
            print("PDF saved to Photos successfully, but may not display properly")
            
        } catch {
            // If saving as photo fails, throw a more specific error for PDFs
            print("Failed to save PDF to Photos: \(error.localizedDescription)")
            throw ExportError.pdfSaveNotSupported
        }
    }
    
    /// Export converted image to Files
    func exportToFiles(_ image: UIImage, format: ConversionFormat) async throws -> URL {
        let data = try await getImageData(image, format: format)
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = "converted_image_\(Date().timeIntervalSince1970).\(format.fileExtension)"
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        try data.write(to: fileURL)
        return fileURL
    }
    
    /// Export PDF data directly to Files (for multi-page PDFs)
    func exportPDFDataToFiles(_ pdfData: Data) async throws -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = "multi_page_pdf_\(Date().timeIntervalSince1970).pdf"
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        try pdfData.write(to: fileURL)
        return fileURL
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
        case .pdf:
            // For PDF, we need to create the actual PDF data
            let pdfData = try await createPDFData(from: correctedImage)
            
            // Validate that we actually got PDF data
            guard pdfData.count > 0 else {
                throw ExportError.failedToGetImageData
            }
            
            // Check if the data starts with PDF signature
            let pdfHeader = pdfData.prefix(4)
            if pdfHeader != "%PDF".data(using: .ascii) {
                print("Warning: Generated data doesn't have PDF header")
            }
            
            return pdfData
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
    
    /// Create PDF data from image
    private func createPDFData(from image: UIImage) async throws -> Data {
        let pdfData = NSMutableData()
        let pdfConsumer = CGDataConsumer(data: pdfData as CFMutableData)!
        
        // Ensure the image size is reasonable for PDF
        var mediaBox = CGRect(origin: .zero, size: image.size)
        
        // If image is too large, scale it down to reasonable PDF dimensions
        let maxDimension: CGFloat = 2000
        if mediaBox.width > maxDimension || mediaBox.height > maxDimension {
            let scale = min(maxDimension / mediaBox.width, maxDimension / mediaBox.height)
            mediaBox.size = CGSize(width: mediaBox.width * scale, height: mediaBox.height * scale)
        }
        
        guard let pdfContext = CGContext(consumer: pdfConsumer, mediaBox: &mediaBox, nil) else {
            throw ExportError.failedToGetImageData
        }
        
        pdfContext.beginPage(mediaBox: &mediaBox)
        
        if let cgImage = image.cgImage {
            // Draw the image centered in the media box
            let imageRect = AVMakeRect(aspectRatio: image.size, insideRect: mediaBox)
            pdfContext.draw(cgImage, in: imageRect)
        }
        
        pdfContext.endPage()
        pdfContext.closePDF()
        
        return pdfData as Data
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
    case pdfSaveNotSupported
    
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
        case .pdfSaveNotSupported:
            return "PDFs cannot be saved directly to Photos"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noPhotoLibraryAccess:
            return "The app will request permission when you try to save"
        case .failedToGetImageData:
            return "Try converting the image again"
        case .failedToSave:
            return "Try using the Files option instead"
        case .permissionDenied:
            return "Go to Settings > Privacy & Security > Photos and enable access for JPG Converter"
        case .pdfSaveNotSupported:
            return "Use the Files option to save PDFs, or convert to an image format first"
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
