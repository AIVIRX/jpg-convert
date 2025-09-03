//
//  FilesPickerView.swift
//  jpg converter
//
//  Created by Maicol Cabreja on 8/31/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct FilesPickerView: View {
    @Binding var isPresented: Bool
    let onImagesSelected: ([URL]) -> Void
    
    @State private var selectedURLs: [URL] = []
    @State private var showDocumentPicker = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if selectedURLs.isEmpty {
                    emptyStateView
                } else {
                    selectedFilesView
                }
                
                Spacer()
                
                // Action buttons
                if !selectedURLs.isEmpty {
                    actionButtonsView
                }
            }
            .padding()
            .navigationTitle("Select Files")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showDocumentPicker = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker(selectedURLs: $selectedURLs)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Files Selected")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Tap the + button to select image files from your device")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                showDocumentPicker = true
            }) {
                HStack {
                    Image(systemName: "folder")
                    Text("Select Files")
                }
                .font(.headline)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
    }
    
    private var selectedFilesView: some View {
        VStack(spacing: 16) {
            Text("Selected Files (\(selectedURLs.count))")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                ForEach(Array(selectedURLs.enumerated()), id: \.offset) { index, url in
                    SelectedFileView(
                        url: url,
                        onRemove: {
                            removeURL(at: index)
                        }
                    )
                }
            }
        }
    }
    
    private var actionButtonsView: some View {
        VStack(spacing: 12) {
            Button(action: {
                onImagesSelected(selectedURLs)
                isPresented = false
            }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Use Selected Files")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            Button("Clear All") {
                selectedURLs.removeAll()
            }
            .font(.subheadline)
            .foregroundColor(.red)
        }
    }
    
    private func removeURL(at index: Int) {
        guard index >= 0 && index < selectedURLs.count else { return }
        selectedURLs.remove(at: index)
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedURLs: [URL]
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let supportedTypes: [UTType] = [
            .jpeg,
            .png,
            .heif,
            .pdf,
            .tiff
        ]
        
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.selectedURLs.append(contentsOf: urls)
            parent.dismiss()
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}

struct SelectedFileView: View {
    let url: URL
    let onRemove: () -> Void
    
    var body: some View {
        ZStack {
            if let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .clipped()
                    .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 120)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: "doc")
                            .font(.title)
                            .foregroundColor(.secondary)
                    )
            }
            
            // Remove button
            VStack {
                HStack {
                    Spacer()
                    
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
                
                Spacer()
            }
            .padding(8)
        }
    }
}

#Preview {
    FilesPickerView(isPresented: .constant(true)) { _ in }
}
