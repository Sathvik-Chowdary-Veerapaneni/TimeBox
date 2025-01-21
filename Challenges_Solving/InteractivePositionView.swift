import SwiftUI

struct InteractivePositionView: View {
    @State private var iconPosition: CGPoint = CGPoint(x: 60, y: 60)
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                // Print coordinates to console
                                print("Touch at \(value.location)")
                                iconPosition = value.location
                            }
                            .onEnded { value in
                                print("Final position: \(value.location)")
                            }
                    )
                
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 40))
                    .position(x: 360, y: 40)
            }
        }
    }
}

struct InteractivePositionView_Previews: PreviewProvider {
    static var previews: some View {
        InteractivePositionView()
    }
}
