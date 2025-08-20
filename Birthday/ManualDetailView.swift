//
//  ManualDetailView.swift
//  Birthday
//
//  Created by Sergio Arcila on 8/20/25.
//

import SwiftUI

struct ManualDetailView: View {
    let item: ManualBirthday
    var onChanged: (() -> Void)?

    @State private var showEdit = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(item.firstName) \(item.lastName)".trimmingCharacters(in: .whitespaces))
                        .font(.title2).bold()
                    Text(headerLine).foregroundStyle(.secondary)
                }.padding(.vertical, 8)
            }

            Section("Birthday") {
                Text(formattedDate)
                Text(countdown).foregroundStyle(.secondary)
            }

            if let y = item.year {
                Section("Age") { Text("Turns \(turningAge(y))") }
            }

            Section {
                Button("Edit") { showEdit = true }
                    .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("Contact")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEdit) {
            EditManualBirthdayView(item: item) { onChanged?() }
        }
    }

    private var formattedDate: String {
        let d = Calendar.current.date(from: DateComponents(year: item.year ?? 2000, month: item.month, day: item.day))!
        let df = DateFormatter(); df.dateFormat = "EEE, MMM d" + (item.year == nil ? "" : ", yyyy")
        return df.string(from: d)
    }
    private var countdown: String {
        let d = daysUntilNext(item.month, item.day)
        return d == 0 ? "Today 🎉" : "In \(d) \(d == 1 ? "day" : "days")"
    }
    private var headerLine: String {
        "\(formattedDate) · \(countdown)"
    }
    private func daysUntilNext(_ month: Int, _ day: Int) -> Int {
        let cal = Calendar.current
        func nextDate() -> Date {
            var comps = DateComponents(year: cal.component(.year, from: Date()), month: month, day: day)
            var date = cal.date(from: comps)!
            if cal.startOfDay(for: date) < cal.startOfDay(for: Date()) {
                comps.year! += 1; date = cal.date(from: comps)!
            }
            return date
        }
        return max(cal.dateComponents([.day],
            from: cal.startOfDay(for: Date()),
            to: cal.startOfDay(for: nextDate())).day ?? 0, 0)
    }
    private func turningAge(_ birthYear: Int) -> Int {
        let nextYear = Calendar.current.component(.year, from: Calendar.current.date(byAdding: .year, value: 0, to: Date())!)
        return nextYear - birthYear
    }
}
