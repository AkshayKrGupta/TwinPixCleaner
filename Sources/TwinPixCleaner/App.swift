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
        ZStack {
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
            .frostBackground()
            .frame(minWidth: 800, minHeight: 600)
            
            QuickLookResponderView(coordinator: viewModel.quickLookCoordinator)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
        }
        .sheet(isPresented: $viewModel.showUserGuide) {
            UserGuideView()
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { viewModel.appError != nil },
                set: { if !$0 { viewModel.appError = nil } }
            ),
            presenting: viewModel.appError
        ) { _ in
            Button("OK") {
                viewModel.appError = nil
            }
        } message: { error in
            Text(error.localizedDescription)
        }
    }
}
