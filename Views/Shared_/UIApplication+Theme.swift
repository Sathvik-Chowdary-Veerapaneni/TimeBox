import UIKit

extension UIApplication {
    func applyTheme(_ choice: String) {
        guard let scene = connectedScenes.first as? UIWindowScene,
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
