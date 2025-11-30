# TwinPixCleaner

<p align="center">
  <img src=".gemini/app_icon.png" alt="TwinPixCleaner Logo" width="128" height="128">
</p>

<p align="center">
  <strong>Smart Duplicate Photo Finder for macOS</strong><br>
  Find and remove duplicate images to free up disk space
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13.0+-blue.svg" alt="macOS 13.0+">
  <img src="https://img.shields.io/badge/Swift-6.0-orange.svg" alt="Swift 6.0">
  <img src="https://img.shields.io/badge/version-1.0.0-green.svg" alt="Version 1.0.0">
</p>

---

## ✨ Features

- 🔍 **Fast Scanning** - Efficient SHA256-based duplicate detection
- 🎯 **100% Accurate** - Finds only exact duplicates, no false positives
- 🗑️ **Safe Deletion** - Files moved to Trash (recoverable)
- ✅ **Multi-Select** - Select multiple images for batch deletion
- 📊 **Smart Sorting** - Sort by size or number of copies
- 🎨 **Beautiful UI** - Native macOS design with dark mode support
- ⌨️ **Keyboard Shortcuts** - ⌘N for new scan, Delete key to remove files
- 🔒 **Privacy First** - All processing happens locally, no data leaves your Mac

## 📥 Installation

### Option 1: Download Release (Recommended)
1. Download the latest release from [Releases](https://github.com/yourusername/TwinPixCleaner/releases)
2. Open the DMG file
3. Drag TwinPixCleaner to your Applications folder
4. Launch from Applications

### Option 2: Build from Source
```bash
# Clone the repository
git clone https://github.com/yourusername/TwinPixCleaner.git
cd TwinPixCleaner

# Build release version
swift build -c release

# Run the app
./.build/release/TwinPixCleaner
```

## 🚀 Quick Start

1. **Launch TwinPixCleaner**
2. **Select a folder** to scan (or drag & drop)
3. **Review duplicates** - sorted by size by default
4. **Select files** to delete (click to select, ⌘-click for multiple)
5. **Delete** - Press Delete key or click "Delete Selected"
6. **Done!** - Files are safely moved to Trash

## 📖 User Guide

### Scanning for Duplicates

**Method 1: Button**
- Click "Select Folder to Scan"
- Choose any folder on your Mac
- Wait for scan to complete

**Method 2: Drag & Drop**
- Drag any folder onto the app window
- Scan starts automatically

**Method 3: Keyboard Shortcut**
- Press ⌘N to start a new scan

### Understanding Results

The results view shows:
- **Duplicate Groups**: Sets of identical images
- **File Size**: Size of each duplicate file
- **Copies**: Number of duplicates found
- **Potential Savings**: Space you can free up

### Sorting Options

Use the sort dropdown to prioritize:
- **Largest First** (default) - Free up space quickly
- **Smallest First** - Start with small files
- **Most Copies** - Files with most duplicates
- **Fewest Copies** - Files with fewer duplicates

### Selecting Files

- **Single Click**: Select/deselect one file
- **Delete Key**: Delete all selected files
- **Hover**: View file details (name, path, date, size)

### Safe Deletion

- All deleted files go to **macOS Trash**
- You can recover files from Trash before emptying
- No permanent deletion without your confirmation

## 🔒 Privacy & Permissions

### Required Permissions

**File Access**
- TwinPixCleaner needs permission to read folders you select
- Granted automatically when you choose a folder

**Full Disk Access** (Optional)
- Required for system folders and external drives
- Enable in: System Settings → Privacy & Security → Full Disk Access
- Add TwinPixCleaner to the list

### Privacy Guarantee

✅ **100% Local Processing** - No cloud, no servers  
✅ **No Data Collection** - We don't track anything  
✅ **No Internet Required** - Works completely offline  
✅ **Open Source** - Verify the code yourself  

Read our full [Privacy Policy](PRIVACY.md)

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘N | New Scan |
| Delete/Backspace | Delete Selected Files |
| ⌘W | Close Window |
| ⌘Q | Quit App |

## 🛠️ Technical Details

- **Language**: Swift 6.0
- **UI Framework**: SwiftUI
- **Minimum macOS**: 13.0 (Ventura)
- **Architecture**: Apple Silicon & Intel
- **Duplicate Detection**: SHA256 hashing
- **File Operations**: Native FileManager APIs

## 📊 Performance

- Scans **1,000+ images** in seconds
- Handles **large libraries** (10,000+ files)
- Low memory footprint
- Optimized for Apple Silicon

## 🤝 Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file for details.

## 👨‍💻 Developer

**Akshay K Gupta**  
[LinkedIn](https://www.linkedin.com/in/akshay-kr-gupta/)

## 🐛 Support

Found a bug or have a feature request?
- Open an [Issue](https://github.com/yourusername/TwinPixCleaner/issues)
- Contact via [LinkedIn](https://www.linkedin.com/in/akshay-kr-gupta/)

## ⭐ Show Your Support

If you find TwinPixCleaner useful, please:
- ⭐ Star this repository
- 📢 Share with friends
- 💬 Leave feedback

---

<p align="center">
  Made with ❤️ for macOS
</p>
