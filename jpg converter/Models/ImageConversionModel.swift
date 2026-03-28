//
//  ImageConversionModel.swift
//  jpg converter
//
//  Created by Maicol Cabreja on 8/31/25.
//

import Foundation
import UIKit

struct ImageConversionModel: Identifiable, Equatable {
    let id = UUID()
    let originalImage: UIImage
    let originalFormat: ConversionFormat
    var convertedImage: UIImage?
    var convertedFormat: ConversionFormat?
    var compressionQuality: Float
    var isProcessing: Bool = false
    var errorMessage: String?
    
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

enum ConversionFormat: String, CaseIterable, Identifiable {
    case jpg = "JPG"
    case png = "PNG"
    case heic = "HEIC"
    case tiff = "TIFF"
    
    var id: String { rawValue }
    
    var fileExtension: String {
        switch self {
        case .jpg: return "jpg"
        case .png: return "png"
        case .heic: return "heic"
        case .tiff: return "tiff"
        }
    }
    
    var mimeType: String {
        switch self {
        case .jpg: return "image/jpeg"
        case .png: return "image/png"
        case .heic: return "image/heic"
        case .tiff: return "image/tiff"
        }
    }
    
    var displayName: String {
        switch self {
        case .jpg: return "JPEG"
        case .png: return "PNG"
        case .heic: return "HEIC"
        case .tiff: return "TIFF"
        }
    }
    
    var description: String {
        switch self {
        case .jpg: return "Universal format"
        case .png: return "Transparency support"
        case .heic: return "Smaller file size"
        case .tiff: return "High quality"
        }
    }
    
    var isLossy: Bool {
        switch self {
        case .jpg: return true
        case .png, .heic, .tiff: return false
        }
    }
}

enum ConversionDirection {
    case fromAny
    
    var title: String {
        return "Convert JPEG to Any Format"
    }
    
    var description: String {
        return "Convert your JPEG photos to PNG, HEIC, TIFF, and more"
    }
    
    var sourceFormats: [ConversionFormat] {
        return [.jpg, .png, .heic, .tiff] // Support all common formats
    }
    
    var targetFormats: [ConversionFormat] {
        return [.jpg, .png, .heic, .tiff] // Include JPG as a target option
    }
}
