# TwinPixCleaner Distribution Guide

This guide explains how to open the project in Xcode, build a proper macOS application, and create a DMG installer for distribution.

## Part 1: Open in Xcode

1. **Launch Xcode**.
2. Click **"Open Existing Project..."**.
3. Navigate to the `TwinPixCleaner` folder (where `Package.swift` is located).
4. Click **Open**.
5. Xcode will detect the `Package.swift` and open it as a Swift Package project.

## Part 2: Run in Xcode

1. In the top toolbar, ensure the scheme selected is **TwinPixCleaner** (icon looks like a terminal executable).
2. Select your Mac ("My Mac") as the destination.
3. Press **⌘R** (Command + R) to build and run.
4. The app should launch.

> **Note**: Running directly from a Package file has limitations (no Info.plist, no proper bundle ID). For distribution, we need to generate a real `.app` bundle.

## Part 3: Create a Standalone App Bundle

Since we are using Swift Package Manager, we can use the command line to build a release version, but to make it a proper double-clickable App for your friends, we need to package it structure correctly.

### Method A: The Quick Way (Command Line)

I have created a script to automate this. Run the following command in your terminal:

```bash
./scripts/build_app.sh
```

*(I will create this script for you in the next step)*

### Method B: The Manual Way (Xcode Project)

If you want a permanent Xcode Project (`.xcodeproj`) for future development:

1. Open Xcode.
2. **File > New > Project**.
3. Choose **macOS > App**.
4. Name it **TwinPixCleaner**.
5. Set Interface to **SwiftUI** and Language to **Swift**.
6. Save it in a *new* folder (e.g., `TwinPixCleanerApp`).
7. **Copy** all files from `Sources/TwinPixCleaner` in your current folder to the new Xcode project folder.
8. Add the files to the Xcode project (drag and drop).
9. Build and Archive from Xcode.

## Part 4: Create a DMG Installer

Once you have the `TwinPixCleaner.app` file (from Method A or B), here is how to make a DMG:

1. **Create a folder** named `Installer`.
2. Put `TwinPixCleaner.app` inside it.
3. (Optional) Add a shortcut to Applications folder:
   - Open Terminal.
   - Run: `ln -s /Applications Installer/Applications`
4. Open **Disk Utility**.
5. Go to **File > New Image > Image from Folder...**.
6. Select the `Installer` folder.
7. Choose **read/write** image format initially.
8. Save as `TwinPixCleaner_RW.dmg`.
9. Open the new DMG, arrange the icons nicely (App on left, Applications shortcut on right).
10. Eject the DMG.
11. Back in Disk Utility: **Images > Convert...**.
12. Select `TwinPixCleaner_RW.dmg`.
13. Choose **compressed** format.
14. Save as `TwinPixCleaner_Installer.dmg`.

**This `TwinPixCleaner_Installer.dmg` is the file you send to your friends!**

## Important Note on Gatekeeper

Since you likely don't have an Apple Developer ID ($99/year), your friends will see a warning:
*"TwinPixCleaner can't be opened because it is from an unidentified developer."*

**Tell your friends to:**
1. **Right-click** (or Control-click) the App.
2. Select **Open**.
3. Click **Open** in the dialog box.
(They only need to do this once).
