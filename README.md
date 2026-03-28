# JPG Converter – Convert to & from JPG

A complete iOS app built with SwiftUI that allows users to convert images between various formats including JPG, PNG, HEIC, and TIFF.

## Features

### Core Features
- **Convert to JPG**: Convert any supported image format (PNG, HEIC, TIFF) to JPG
- **Convert from JPG**: Convert JPG images to PNG, HEIC, and TIFF formats
- **Photo Library Integration**: Select images directly from your Photo Library
- **Batch Conversion**: Convert up to 9 images at once
- **Quality Control**: Adjust JPG compression quality for size/quality tradeoff (Pro feature)
- **Offline Operation**: All conversions happen locally using Core Graphics and Image I/O APIs

### Export Options
- Save converted images to Photos library
- Share via iOS share sheet
- Support for all major image formats

### iOS Integration
- **iOS Shortcuts**: Create automation workflows with "Convert to JPG" and "Convert from JPG" actions
- **Quick Actions**: Long press on app icon for quick conversion options
- **Drag & Drop**: Full iPad support with drag and drop functionality
- **Dark Mode**: Automatic dark mode support

### Freemium Model
- **Free Tier**: Single image conversion, basic features
- **Pro Tier**: Compression slider, unlimited conversions, remove ads

## Technical Architecture

### MVVM Pattern
- **Models**: `ImageConversionModel`, `ConversionFormat`, `ConversionDirection`
- **ViewModels**: `ImageConverterViewModel` - coordinates UI and business logic
- **Views**: SwiftUI views for each screen and component
- **Services**: `ImageConverterService`, `ImageManager` - handle core functionality

### Key Components

#### ImageConverterService
- Handles all image format conversions
- Uses Core Graphics and Image I/O APIs
- Supports async/await for better performance
- Progress tracking for batch operations

#### ImageManager
- Manages image selection from Photos
- Handles export operations
- Photo library permissions management
- File format detection

#### Views
- `ContentView`: Main app interface
- `PhotosPickerView`: Photo library selection
- `ConversionResultsView`: Results display and export

### Supported Formats
- **Input**: JPG, PNG, HEIC, TIFF
- **Output**: JPG, PNG, HEIC, TIFF
- **Quality**: Adjustable compression (0.1 - 1.0)

## Setup Instructions

### Prerequisites
- Xcode 15.0+
- iOS 17.0+ deployment target
- macOS 14.0+ (for development)

### Installation
1. Clone the repository
2. Open `jpg converter.xcodeproj` in Xcode
3. Select your development team in project settings
4. Build and run on device or simulator

### Required Permissions
The app requires the following permissions:
- **Photo Library Access**: For selecting and saving images

### Configuration
- Update bundle identifier in project settings
- Configure signing and capabilities
- Add your App Store Connect app ID for production

## Project Structure

```
jpg converter/
├── Models/
│   └── ImageConversionModel.swift
├── ViewModels/
│   └── ImageConverterViewModel.swift
├── Services/
│   ├── ImageConverterService.swift
│   └── ImageManager.swift
├── Views/
│   ├── PhotosPickerView.swift
│   └── ConversionResultsView.swift
├── Shortcuts/
│   └── ShortcutsIntent.swift
├── Resources/
│   └── Localizable.strings
├── Assets.xcassets/
├── ContentView.swift
├── jpg_converterApp.swift
└── Info.plist
```

## Usage Examples

### Basic Conversion
1. Launch the app
2. Choose conversion direction (to/from JPG)
3. Select images from Photos
4. Adjust quality settings (Pro users)
5. Tap "Convert Images"
6. Export or share results

### iOS Shortcuts Integration
1. Open Shortcuts app
2. Add "Convert to JPG" or "Convert from JPG" action
3. Configure input images and settings
4. Run automation

### Quick Actions
- Long press app icon
- Select "Convert to JPG" or "Convert from JPG"
- Choose images and convert

## Customization

### Adding New Formats
1. Extend `ConversionFormat` enum
2. Add conversion logic in `ImageConverterService`
3. Update UI components to support new format

### Modifying UI
- All views use SwiftUI with modern design patterns
- Customizable colors, fonts, and layouts
- Support for different device sizes and orientations

### Localization
- All strings are externalized in `Localizable.strings`
- Easy to add new languages
- Support for RTL languages

## Performance Considerations

- Image processing happens on background threads
- Memory management for large images
- Progress tracking for batch operations
- Efficient format detection and conversion

## Testing

### Unit Tests
- Test conversion logic with sample images
- Verify format detection accuracy
- Test error handling scenarios

### UI Tests
- Test image selection flows
- Verify conversion process
- Test export and sharing functionality

## Deployment

### App Store
1. Configure app metadata and screenshots
2. Set up in-app purchase for Pro features
3. Submit for review

### Enterprise Distribution
- Configure enterprise signing
- Distribute via MDM or direct installation

## Future Enhancements

- Cloud storage integration (iCloud, Dropbox, Google Drive)
- Advanced image editing features
- Video format support
- Web interface for desktop users
- API for third-party integrations

## Contributing

1. Fork the repository
2. Create a feature branch
3. Implement changes with proper testing
4. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions:
- Create an issue in the repository
- Contact the development team
- Check the documentation

## Changelog

### Version 1.0.0
- Initial release
- Core conversion functionality
- iOS Shortcuts integration
- Pro features and freemium model
- Full iOS 17 compatibility
