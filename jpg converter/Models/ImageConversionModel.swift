//
//  ImageConversionModel.swift
//  jpg converter
//
//  Created by Maicol Cabreja on 8/31/25.
//

import Foundation
import UIKit

// MARK: - Image Conversion Model
struct ImageConversionModel: Identifiable, Equatable {
    let id = UUID()
    let originalImage: UIImage
    let originalFormat: ConversionFormat
    var convertedImage: UIImage?
    var convertedFormat: ConversionFormat?
    var compressionQuality: Float
    var isProcessing: Bool = false
    var errorMessage: String?
    
    // Store PDF data for multi-page PDFs
    var pdfData: Data?
    
    // Computed properties
    var originalSize: Int {
        if let data = originalImage.jpegData(compressionQuality: 1.0) {
            return data.count
        }
        return 0
    }
    
    var convertedSize: Int {
        if let convertedImage = convertedImage,
           let data = convertedImage.jpegData(compressionQuality: 1.0) {
            return data.count
        }
        return 0
    }
    
    var sizeReduction: Double {
        guard convertedSize > 0 else { return 0 }
        return Double(originalSize - convertedSize) / Double(originalSize) * 100
    }
}

// MARK: - Conversion Format Enum
enum ConversionFormat: String, CaseIterable, Identifiable {
    case jpg = "JPG"
    case png = "PNG"
    case heic = "HEIC"
    case pdf = "PDF"
    case tiff = "TIFF"
    
    var id: String { rawValue }
    
    var fileExtension: String {
        switch self {
        case .jpg: return "jpg"
        case .png: return "png"
        case .heic: return "heic"
        case .pdf: return "pdf"
        case .tiff: return "tiff"
        }
    }
    
    var mimeType: String {
        switch self {
        case .jpg: return "image/jpeg"
        case .png: return "image/png"
        case .heic: return "image/heic"
        case .pdf: return "application/pdf"
        case .tiff: return "image/tiff"
        }
    }
    
    var displayName: String {
        switch self {
        case .jpg: return "JPEG"
        case .png: return "PNG"
        case .heic: return "HEIC"
        case .pdf: return "PDF"
        case .tiff: return "TIFF"
        }
    }
    
    var description: String {
        switch self {
        case .jpg: return "Universal format"
        case .png: return "Transparency support"
        case .heic: return "Smaller file size"
        case .pdf: return "Document format"
        case .tiff: return "High quality"
        }
    }
    
    var isLossy: Bool {
        switch self {
        case .jpg: return true
        case .png, .heic, .pdf, .tiff: return false
        }
    }
}

// MARK: - Conversion Direction
enum ConversionDirection {
    case fromJPG
    
    var title: String {
        return "Convert JPG to Other Formats"
    }
    
    var description: String {
        return "Convert your JPG photos to PNG, HEIC, PDF, and more"
    }
    
    var sourceFormats: [ConversionFormat] {
        return [.jpg]
    }
    
    var targetFormats: [ConversionFormat] {
        return [.png, .heic, .pdf, .tiff]
    }
}
