import AppKit

/// Loads the app icon for display inside the UI (distinct from the .icns bundle icon).
/// Shared by `DashboardView` and `ResultsView`, which both show it in their headers.
func loadAppIcon() -> NSImage? {
    // Try loading from named asset (works in development with swift run)
    if let image = NSImage(named: "AppIcon") {
        return image
    }

    // Try loading from resource bundle (works in packaged .app)
    if let resourceBundle = Bundle.main.url(forResource: "TwinPixCleaner_TwinPixCleaner", withExtension: "bundle"),
       let bundle = Bundle(url: resourceBundle),
       let imagePath = bundle.path(forResource: "AppIcon", ofType: "png"),
       let image = NSImage(contentsOfFile: imagePath) {
        return image
    }

    return nil
}
