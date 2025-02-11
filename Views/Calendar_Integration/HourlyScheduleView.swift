import SwiftUI

struct HourlyScheduleView: View {
    // Generate an array of dates representing each hour of the current day
    private let hours: [Date] = {
        var arr: [Date] = []
        let calendar = Calendar.current
        let today = Date()
        for hour in 0..<24 {
            if let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: today) {
                arr.append(date)
            }
        }
        return arr
    }()
    
    var body: some View {
        NavigationView {
            List(hours, id: \.self) { hour in
                HStack {
                    Text(formattedHour(for: hour))
                        .frame(width: 80, alignment: .leading)
                    Divider()
                    // Placeholder text; replace with dynamic content if needed
                    Text("TaskBox")
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            .navigationTitle("Hourly Schedule")
        }
    }
    
    // Helper function to format the hour (e.g., "12:00 AM")
    private func formattedHour(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

struct HourlyScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        HourlyScheduleView()
    }
}
