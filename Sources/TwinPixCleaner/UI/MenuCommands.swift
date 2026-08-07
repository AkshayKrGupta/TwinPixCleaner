import SwiftUI

struct MenuCommands: Commands {
    @ObservedObject var viewModel: AppViewModel
    
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(AppConstants.Strings.newScan) {
                viewModel.reset()
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(viewModel.state == .scanning)
        }

        CommandGroup(replacing: .undoRedo) {
            Button(AppConstants.Strings.undoDelete) {
                viewModel.undoLastDeletion()
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(!viewModel.canUndo)
        }

        CommandGroup(replacing: .help) {
            Button("TwinPixCleaner Help") {
                viewModel.showUserGuide = true
            }
            .keyboardShortcut("?", modifiers: .command)
        }

        CommandGroup(replacing: .appInfo) {
            Button("About TwinPixCleaner") {
                let info = Bundle.main.infoDictionary
                let version = info?["CFBundleShortVersionString"] as? String ?? "2.0.0"
                let build = info?["CFBundleVersion"] as? String ?? "1"
                NSApplication.shared.orderFrontStandardAboutPanel(
                    options: [
                        .applicationName: AppConstants.Strings.appName,
                        .applicationVersion: version,
                        .version: "Build \(build)",
                        .credits: NSAttributedString(string: "Developed by \(AppConstants.Strings.developerName)\n\(AppConstants.Strings.aboutDescription)")
                    ]
                )
            }
        }
    }
}
