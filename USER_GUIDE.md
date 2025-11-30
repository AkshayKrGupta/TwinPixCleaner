# TwinPixCleaner User Guide

## Table of Contents
1. [Getting Started](#getting-started)
2. [Scanning for Duplicates](#scanning-for-duplicates)
3. [Reviewing Results](#reviewing-results)
4. [Deleting Duplicates](#deleting-duplicates)
5. [Tips & Best Practices](#tips--best-practices)
6. [Troubleshooting](#troubleshooting)

---

## Getting Started

### First Launch

When you first open TwinPixCleaner, you'll see the dashboard with:
- App logo and title
- Feature highlights
- "Select Folder to Scan" button
- Developer information

### Granting Permissions

For best results, grant Full Disk Access:

1. Open **System Settings**
2. Go to **Privacy & Security**
3. Click **Full Disk Access**
4. Click the **+** button
5. Navigate to Applications and select **TwinPixCleaner**
6. Toggle the switch to enable

> **Note**: This is optional but recommended for scanning system folders and external drives.

---

## Scanning for Duplicates

### Method 1: Select Folder Button

1. Click **"Select Folder to Scan"**
2. Navigate to the folder you want to scan
3. Click **"Open"**
4. Scanning begins automatically

**Recommended Folders to Scan:**
- `~/Pictures` - Your Photos library
- `~/Downloads` - Downloaded images
- `~/Desktop` - Desktop files
- External drives - USB drives, SD cards

### Method 2: Drag & Drop

1. Open Finder
2. Locate the folder you want to scan
3. Drag the folder onto the TwinPixCleaner window
4. Release to start scanning

### Method 3: Keyboard Shortcut

Press **⌘N** (Command + N) to open the folder picker

### Scanning Modes

TwinPixCleaner offers two scanning modes:

**1. Exact Match (Default)**
- Finds files that are bit-for-bit identical
- Uses SHA-256 hashing for 100% accuracy
- Safe to delete any copy - they're completely identical
- Fast and efficient

**2. Visual Similarity**
- Finds images that look similar but may have differences
- Uses Apple's Vision framework for perceptual analysis
- Detects similar images with different:
  - File sizes or resolutions
  - Compression levels
  - Minor edits or crops
  - File formats (JPG vs PNG of same image)

**Similarity Threshold Slider:**
- **Strict (Left)**: Only finds nearly identical images
- **Loose (Right)**: Finds images with more visible differences
- Adjust based on your needs
- Start with default (middle) and adjust if needed

> **Tip**: Use Exact Match for finding true duplicates to delete. Use Visual Similarity to find similar photos you may want to review manually.

### During Scanning

You'll see:
- Progress bar showing completion percentage
- Current file being processed
- **Cancel Scan** button to stop

**Scanning Time:**
- Small folders (< 100 files): Seconds
- Medium folders (100-1,000 files): Under a minute
- Large folders (1,000-10,000 files): 1-5 minutes
- Very large folders (10,000+ files): 5-15 minutes

---

## Reviewing Results

### Understanding the Results View

**Header Section:**
- App logo and title
- Sort dropdown menu
- Delete/New Scan buttons

**Footer Bar (Bottom):**
- **Duplicate Groups**: Number of sets found
- **Total Duplicates**: Total duplicate files
- **Can Be Freed**: Potential disk space savings
- **Selection Counter**: Number of files selected

### Duplicate Groups

Each group shows:
- **Group Header**: "Duplicate Set" with file size and copy count
- **Image Previews**: Horizontal scrollable list
- **File Information**: Name and full path below each image

### Sorting Results

Click the **sort dropdown** to change order:

**Largest First** (Default)
- Shows biggest files first
- Best for maximizing space savings
- Recommended for most users

**Smallest First**
- Shows smallest files first
- Useful for quick cleanup

**Most Copies**
- Shows files with most duplicates first
- Good for finding heavily duplicated images

**Fewest Copies**
- Shows files with fewest duplicates first
- Useful for targeted cleanup

### Viewing File Details

**Hover over any image** to see:
- File name
- Full file path
- Creation date
- File size

This helps you decide which copy to keep.

---

## Deleting Duplicates

### Selecting Files

**Single Selection:**
- Click on any image to select it
- Selected images show a blue border and checkmark
- Click again to deselect

**Multiple Selection:**
- Click multiple images to select them
- All selected files show in the footer counter

**Keyboard Selection:**
- Use mouse/trackpad to click images
- Press **Delete** or **Backspace** to remove selected files

### Deletion Methods

**Method 1: Delete Button (Header)**
1. Select one or more files
2. Click **"Delete X Selected"** button in header
3. Files are moved to Trash

**Method 2: Delete Key**
1. Select one or more files
2. Press **Delete** or **Backspace** key
3. Files are moved to Trash

**Method 3: Individual Delete**
1. Click **"Move to Trash"** button on any image
2. That single file is moved to Trash

### After Deletion

- Deleted files are **removed from the list**
- Groups with only 1 remaining file are **removed**
- Footer stats **update automatically**
- Files are **in Trash** (recoverable)

### Recovering Deleted Files

If you deleted a file by mistake:

1. Open **Finder**
2. Click **Trash** in the sidebar
3. Find the deleted file
4. Right-click and select **"Put Back"**
5. File is restored to original location

> **Important**: Empty Trash only when you're sure you don't need the files!

---

## Tips & Best Practices

### Before Scanning

✅ **Backup Important Files**
- Always have a backup before deleting files
- Use Time Machine or cloud backup

✅ **Start Small**
- Test on a small folder first
- Get familiar with the interface

✅ **Close Other Apps**
- For faster scanning, close memory-intensive apps

### During Review

✅ **Check File Paths**
- Hover to see where each file is located
- Keep files in organized locations
- Delete files from messy folders (Downloads, Desktop)

✅ **Sort by Largest First**
- Free up the most space quickly
- Focus on big files first

✅ **Review Before Deleting**
- Make sure you're keeping the right copy
- Check file locations and dates

### Choosing Which Copy to Keep

**Keep the file that is:**
- In a more organized location (e.g., Photos library vs. Downloads)
- In your main photo library
- Has a better filename
- Is in a backed-up location

**Delete the file that is:**
- In Downloads or Desktop
- Has a generic name (e.g., "IMG_1234.jpg")
- Is a duplicate in a temporary location

### After Deletion

✅ **Review Trash**
- Check Trash before emptying
- Make sure you didn't delete anything important

✅ **Empty Trash**
- Free up disk space permanently
- Only when you're certain

✅ **Run Regular Scans**
- Scan monthly to keep your Mac clean
- Prevent duplicate buildup

---

## Troubleshooting

### App Won't Scan Certain Folders

**Problem**: "Permission denied" or folder won't scan

**Solution**:
1. Grant Full Disk Access (see Getting Started)
2. Make sure you own the folder
3. Try scanning a subfolder instead

### Scan is Very Slow

**Problem**: Scanning takes too long

**Solutions**:
- Close other apps to free up memory
- Scan smaller folders
- Avoid scanning network drives
- Check if your Mac is low on storage

### No Duplicates Found

**Problem**: Scan completes but shows "No duplicates found"

**Possible Reasons**:
- Folder actually has no duplicates (good!)
- Files are similar but not identical
- Different file formats (JPG vs. PNG)
- Images are edited versions (not exact copies)

**Note**: In Exact Match mode, TwinPixCleaner only finds **exact** duplicates. Switch to Visual Similarity mode to find similar (but not identical) images.

### Can't Delete Files

**Problem**: Delete button doesn't work or files won't delete

**Solutions**:
1. Check if files are open in another app
2. Verify you have write permissions
3. Try restarting TwinPixCleaner
4. Check if disk is full

### App Crashes During Scan

**Problem**: App quits unexpectedly

**Solutions**:
1. Update to latest macOS version
2. Restart your Mac
3. Scan smaller folders
4. Check Console app for error logs
5. Contact developer with crash report

### Deleted Wrong File

**Problem**: Accidentally deleted the wrong copy

**Solution**:
1. Open Trash immediately
2. Find the file
3. Right-click → "Put Back"
4. File returns to original location

**Prevention**:
- Always hover to check file details
- Review selections before deleting
- Start with small batches

---

## Keyboard Shortcuts Reference

| Shortcut | Action |
|----------|--------|
| ⌘N | Start new scan |
| Delete/Backspace | Delete selected files |
| ⌘W | Close window |
| ⌘Q | Quit app |
| Click | Select/deselect file |
| Hover | View file details |

---

## Getting Help

### Still Need Help?

**Contact Developer:**
- LinkedIn: [Akshay K Gupta](https://www.linkedin.com/in/akshay-kr-gupta/)
- GitHub Issues: Report bugs or request features

**Before Contacting:**
- Check this guide thoroughly
- Try restarting the app
- Update to latest version
- Note any error messages

---

## Privacy & Safety

### Your Data is Safe

✅ All processing happens on your Mac  
✅ No internet connection required  
✅ No data sent to any server  
✅ No tracking or analytics  
✅ Files only moved to Trash (recoverable)  

### Best Practices

- Always backup before mass deletions
- Review Trash before emptying
- Keep important files in organized locations
- Run regular scans to prevent buildup

---

<p align="center">
  <strong>Happy Cleaning! 🎉</strong><br>
  Keep your Mac organized and free up valuable disk space
</p>
