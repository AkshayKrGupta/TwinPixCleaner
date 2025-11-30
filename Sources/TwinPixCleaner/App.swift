import SwiftUI

@main
struct TwinPixCleanerApp: App {
    @StateObject private var viewModel = AppViewModel()
    @AppStorage("appTheme") private var currentTheme: AppTheme = .system
    
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .preferredColorScheme(currentTheme.colorScheme)
        }
        .commands {
            MenuCommands(viewModel: viewModel)
        }
    }
}

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        Group {
            switch viewModel.state {
            case .idle:
                DashboardView(viewModel: viewModel)
            case .scanning:
                ScanningView(viewModel: viewModel)
            case .results(let groups):
                ResultsView(viewModel: viewModel, groups: groups)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .sheet(isPresented: $viewModel.showUserGuide) {
            UserGuideView()
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}
