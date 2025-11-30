import SwiftUI

struct MenuCommands: Commands {
    @ObservedObject var viewModel: AppViewModel
    
    var body: some Commands {
        // Replace default "New" command
        CommandGroup(replacing: .newItem) {
            Button("New Scan") {
                viewModel.reset()
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(viewModel.state == .scanning)
        }
        
        // Help menu
        CommandGroup(replacing: .help) {
            Button("TwinPixCleaner Help") {
                if let url = URL(string: "https://www.linkedin.com/in/akshay-kr-gupta/") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
        
        // App Info
        CommandGroup(replacing: .appInfo) {
            Button("About TwinPixCleaner") {
                NSApplication.shared.orderFrontStandardAboutPanel(
                    options: [
                        .applicationName: "TwinPixCleaner",
                        .applicationVersion: "1.0.0",
                        .version: "Build 1",
                        .credits: NSAttributedString(string: "Developed by Akshay K Gupta\nA smart duplicate photo finder for macOS")
                    ]
                )
            }
        }
    }
}
