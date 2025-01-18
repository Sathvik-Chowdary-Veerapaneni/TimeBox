import SwiftUI
import Combine

class TimeBoxViewModel: ObservableObject {
    // Published properties for the "top priorities" and "brain dump"
    @Published var topPriority1: String = ""
    @Published var topPriority2: String = ""
    @Published var topPriority3: String = ""
    @Published var brainDump: String = ""

    // Example of a reset or save method
    func resetFields() {
        topPriority1 = ""
        topPriority2 = ""
        topPriority3 = ""
        brainDump = ""
    }
}
