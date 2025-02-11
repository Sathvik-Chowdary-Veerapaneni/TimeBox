import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Store the theme choice in AppStorage
    @AppStorage("userThemeChoice") private var userThemeChoice: String = "system"
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Theme")) {
                    Picker("Select Theme", selection: $userThemeChoice) {
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                        Text("System").tag("system")
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Profile & Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            UIApplication.shared.applyTheme(userThemeChoice)
        }
        .onChange(of: userThemeChoice) { newValue in
            UIApplication.shared.applyTheme(newValue)
        }
    }
    
    private func applyThemeChoice(_ choice: String) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
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
}
