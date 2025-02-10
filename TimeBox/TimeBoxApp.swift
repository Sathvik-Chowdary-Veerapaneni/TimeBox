import SwiftUI

@main
struct TimeBoxApp: App {
    // Read the user’s theme choice from UserDefaults
    @AppStorage("userThemeChoice") private var userThemeChoice: String = "system"
    
    let persistenceController = PersistenceController.shared
    @StateObject private var taskVM: TaskViewModel
    
    init() {
        let context = persistenceController.container.viewContext
        _taskVM = StateObject(wrappedValue: TaskViewModel(context: context))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(taskVM)
                .onAppear {
                    DispatchQueue.main.async {
                        UIApplication.shared.applyTheme(userThemeChoice)
                    }
                }
                .onChange(of: userThemeChoice) { newValue in
                    UIApplication.shared.applyTheme(newValue)
                }
        }
    }
    
    private func applyThemeChoice(_ choice: String) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return
        }
        switch choice {
        case "light":
            window.overrideUserInterfaceStyle = .light
        case "dark":
            window.overrideUserInterfaceStyle = .dark
        default:
            window.overrideUserInterfaceStyle = .unspecified
        }
    }
}
