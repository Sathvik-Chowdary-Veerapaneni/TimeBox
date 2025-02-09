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
        
        // Remove applyThemeChoice() from here because the window might not exist yet.
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(taskVM)
                // 1) When the main content appears, apply the stored theme
                .onAppear {
                    DispatchQueue.main.async {
                        applyThemeChoice(userThemeChoice)
                    }
                }
                // 2) If the user changes the theme while in the app, re-apply immediately
                .onChange(of: userThemeChoice) { newValue in
                    applyThemeChoice(newValue)
                }
        }
    }
    
    /// Applies the user's preferred theme (light, dark, or system).
    /// We look up the first available window in the current scene.
    private func applyThemeChoice(_ choice: String) {
        // This approach is more reliable than UIApplication.shared.windows.first in SwiftUI.
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
