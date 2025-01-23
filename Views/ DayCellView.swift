// DayCellView.swift

import SwiftUI
import UniformTypeIdentifiers

struct DayCellView: View {
    let day: Date
    let selectedDate: Date
    let dayTaskCount: Int
    
    // Tap to select day
    let onTap: () -> Void
    
    // Called when a string (objectID) is dropped on this day
    // Return `true` if handled
    let onDropTask: (String) -> Bool
    
    @State private var isTargeted = false
    
    var body: some View {
        let isToday = Calendar.current.isDateInToday(day)
        let isSelected = Calendar.current.isDate(day, inSameDayAs: selectedDate)
        let isPast = Calendar.current.startOfDay(for: day) < Calendar.current.startOfDay(for: Date())
        
        ZStack(alignment: .topTrailing) {
            Text("\(Calendar.current.component(.day, from: day))")
                .frame(width: 28, height: 28)
                .foregroundColor(isToday ? .white : .primary)
                .background(
                    Circle().fill(
                        isToday
                            ? Color.blue
                            : isSelected
                                ? Color.blue.opacity(0.2)
                                : isPast
                                    ? Color.gray.opacity(0.2)
                                    : Color.clear
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.gray.opacity(0.4), lineWidth: 0.5)
                )
                .onTapGesture {
                    onTap()
                }
                // DRAG & DROP
                .onDrop(of: [UTType.plainText], isTargeted: $isTargeted) { providers in
                    // Disallow dropping on the past
                    if isPast {
                        print("DEBUG: Disallow dropping on a past date:", day)
                        return false
                    }
                    guard let provider = providers.first else { return false }
                    provider.loadObject(ofClass: String.self) { objectIDString, error in
                        if let error = error {
                            print("DayCellView: loadObject error ->", error)
                            return
                        }
                        guard let objectIDString = objectIDString else { return }
                        // Call onDropTask on the main thread
                        DispatchQueue.main.async {
                            let result = onDropTask(objectIDString)
                            print("DayCellView: onDropTask =>", result)
                        }
                    }
                    return true
                }
            
            // Task count badge
            if dayTaskCount > 0 {
                Text("\(dayTaskCount)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(5)
                    .background(Color.red)
                    .clipShape(Circle())
                    .offset(x: 9.5, y: -10)
            }
        }
    }
}
