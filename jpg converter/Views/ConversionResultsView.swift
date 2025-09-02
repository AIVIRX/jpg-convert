//
//  ConversionResultsView.swift
//  jpg converter
//
//  Created by Maicol Cabreja on 8/31/25.
//

import SwiftUI

struct ConversionResultsView: View {
    @Binding var isPresented: Bool
    let viewModel: ImageConverterViewModel
    
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Results Content
                ScrollView {
                    VStack(spacing: 20) {
                        // Summary
                        summaryView
                        
                        // Converted Images Grid
                        convertedImagesView
                        
                        // Export Options
                        exportOptionsView
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Conversion Results")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("\(viewModel.selectedImages.count) image\(viewModel.selectedImages.count == 1 ? "" : "s") converted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    Task {
                        await shareAllImages()
                    }
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            Divider()
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Summary View
    private var summaryView: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Conversion Complete")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    Text("All images have been successfully converted")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.green)
            }
            
            // Stats
            HStack(spacing: 20) {
                StatItem(
                    title: "Original",
                    value: "\(viewModel.selectedImages.count)",
                    icon: "photo"
                )
                
                StatItem(
                    title: "Converted",
                    value: "\(viewModel.selectedImages.filter { $0.convertedImage != nil }.count)",
                    icon: "checkmark.circle"
                )
                
                StatItem(
                    title: "Errors",
                    value: "\(viewModel.selectedImages.filter { $0.errorMessage != nil }.count)",
                    icon: "exclamationmark.triangle"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Converted Images View
    private var convertedImagesView: some View {
        VStack(spacing: 16) {
            Text("Converted Images")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                ForEach(Array(viewModel.selectedImages.enumerated()), id: \.element.id) { index, imageModel in
                    ConvertedImageView(
                        imageModel: imageModel,
                        onExport: { format in
                            exportImage(imageModel, format: format)
                        },
                        onShare: {
                            shareImage(imageModel)
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Export Options View
    private var exportOptionsView: some View {
        VStack(spacing: 16) {
            Text("Download & Export")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Choose how you want to save your converted images")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                // Primary download option - most prominent
                ExportOptionButton(
                    title: "📥 Download All Images",
                    icon: "arrow.down.circle.fill",
                    action: {
                        Task {
                            await downloadAllImages()
                        }
                    }
                )
                
                ExportOptionButton(
                    title: "Save All to Photos",
                    icon: "photo.on.rectangle",
                    action: {
                        Task {
                            await viewModel.exportAllImages()
                        }
                    }
                )
                
                ExportOptionButton(
                    title: "Save All to Files",
                    icon: "folder",
                    action: {
                        Task {
                            await saveAllToFiles()
                        }
                    }
                )
                
                ExportOptionButton(
                    title: "Share All Images",
                    icon: "square.and.arrow.up",
                    action: {
                        Task {
                            await shareAllImages()
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func exportImage(_ imageModel: ImageConversionModel, format: ConversionFormat) {
        guard let convertedImage = imageModel.convertedImage else { return }
        
        Task {
            await viewModel.exportToPhotos(convertedImage, format: format)
        }
    }
    
    private func shareImage(_ imageModel: ImageConversionModel) {
        guard let convertedImage = imageModel.convertedImage,
              let convertedFormat = imageModel.convertedFormat else { return }
        
        Task {
            let items = await viewModel.shareImage(convertedImage, format: convertedFormat)
            await MainActor.run {
                shareItems = items
                showShareSheet = true
            }
        }
    }
    
    private func shareAllImages() async {
        let items = await viewModel.getAllConvertedImagesForSharing()
        await MainActor.run {
            shareItems = items
            showShareSheet = true
        }
    }
    
    private func downloadAllImages() async {
        // This will trigger the share sheet with all converted images
        // Users can then choose where to save them
        await shareAllImages()
    }
    
    private func saveAllToFiles() async {
        // Save all images to Files app
        for imageModel in viewModel.selectedImages {
            guard let convertedImage = imageModel.convertedImage,
                  let convertedFormat = imageModel.convertedFormat else { continue }
            
            await viewModel.exportToFiles(convertedImage, format: convertedFormat, imageModel: imageModel)
        }
    }
}

// MARK: - Stat Item
struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Converted Image View
struct ConvertedImageView: View {
    let imageModel: ImageConversionModel
    let onExport: (ConversionFormat) -> Void
    let onShare: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                if let convertedImage = imageModel.convertedImage {
                    Image(uiImage: convertedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 140)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 140)
                        .cornerRadius(8)
                        .overlay(
                            Image(systemName: "exclamationmark.triangle")
                                .font(.title)
                                .foregroundColor(.red)
                        )
                }
                
                // Error overlay
                if imageModel.errorMessage != nil {
                    VStack {
                        Spacer()
                        
                        Text("Error")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                    .padding(8)
                }
            }
            
            VStack(spacing: 8) {
                // Format info
                HStack {
                    Text(imageModel.originalFormat.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if let convertedFormat = imageModel.convertedFormat {
                        Text(convertedFormat.displayName)
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    } else {
                        Text("Failed")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                // Size info
                if imageModel.convertedImage != nil {
                    HStack {
                        Text("\(formatFileSize(imageModel.originalSize))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("\(formatFileSize(imageModel.convertedSize))")
                            .font(.caption2)
                            .foregroundColor(.accentColor)
                    }
                }
                
                // Action buttons
                if imageModel.convertedImage != nil {
                    VStack(spacing: 8) {
                        // Download button - more prominent
                        Button(action: {
                            if let format = imageModel.convertedFormat {
                                onExport(format)
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.caption)
                                Text("Download")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.accentColor)
                            .cornerRadius(8)
                        }
                        
                        // Share button
                        Button(action: onShare) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.caption)
                                Text("Share")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
            }
        }
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Export Option Button
struct ExportOptionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ConversionResultsView(isPresented: .constant(true), viewModel: ImageConverterViewModel())
}
