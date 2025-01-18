import SwiftUI

struct TimeBoxView: View {
    // Adopt the view model as a StateObject so it stays alive
    @StateObject private var viewModel = TimeBoxViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Top Priorities")
                .font(.headline)

            TextField("1", text: $viewModel.topPriority1)
            TextField("2", text: $viewModel.topPriority2)
            TextField("3", text: $viewModel.topPriority3)

            Text("Brain Dump")
                .font(.headline)

            TextEditor(text: $viewModel.brainDump)
                .frame(height: 200)
                .border(Color.secondary)

            Button("Reset") {
                viewModel.resetFields()
            }
            .padding(.top)

            Spacer()
        }
        .padding()
        .navigationTitle("Time Box")
    }
}
