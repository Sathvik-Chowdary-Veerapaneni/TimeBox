// DayCellView.swift
import SwiftUI
import UniformTypeIdentifiers

struct DayCellView: View {
    let day: Date
    let selectedDate: Date
    let dayTaskCount: Int
    let dayDoneCount: Int
    
    let onTap: () -> Void
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
            // CHANGED: onTapGesture
                   .onTapGesture {
                       HapticManager.lightImpact()
                       onTap()
                   }
                   // CHANGED: onDrop
                   .onDrop(of: [UTType.plainText], isTargeted: $isTargeted) { providers in
                       if isPast { return false }
                       guard let provider = providers.first else { return false }
                       _ = provider.loadObject(ofClass: String.self) { objectIDString, error in
                           if let error = error { print("DayCellView error:", error); return }
                           guard let objectIDString = objectIDString else { return }
                           DispatchQueue.main.async {
                               _ = onDropTask(objectIDString)
                           }
                       }
                       return true
                   }

            if dayTaskCount > 0 {
                let badgeColor: Color = (dayDoneCount == dayTaskCount) ? .green : .red
                Text("\(dayTaskCount)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(5)
                    .background(badgeColor)
                    .clipShape(Circle())
                    .offset(x: 9.5, y: -10)
            }
        }
    }
}
