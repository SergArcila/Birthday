//
//  ContentView.swift
//  Birthday
//
//  Created by Sergio Arcila on 8/19/25.
//

import SwiftUI
import Contacts
import UIKit

struct ContentView: View {
    @State private var birthdays: [ContactBirthday] = []
    @State private var isLoading = false
    @State private var showAccessAlert = false

    var body: some View {
        NavigationStack {
            List {
                if birthdays.isEmpty {
                    ContentUnavailableView(
                        "No birthdays found",
                        systemImage: "gift",
                        description: Text("Allow Contacts access and make sure contacts have birthdays.")
                    )
                } else {
                    ForEach(sortedBirthdays) { b in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(b.givenName) \(b.familyName)")
                                    .font(.headline)
                                Text("\(formattedMonthDay(b.month, b.day)) · \(countdownString(b.month, b.day))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("🎂")
                        }
                    }
                }
            }
            .navigationTitle("Birthdays")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await reload() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task { await reload() }
        .alert("Contacts Access Needed", isPresented: $showAccessAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please allow access to Contacts so we can show birthdays.")
        }
    }

    // MARK: - Derived data & helpers
    var sortedBirthdays: [ContactBirthday] {
        birthdays.sorted { nextDate($0.month, $0.day) < nextDate($1.month, $1.day) }
    }

    func reload() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let granted = try await ContactsProvider.requestAccess()
            guard granted else { showAccessAlert = true; return }
            let items = try await ContactsProvider.fetchBirthdays()
            await MainActor.run { birthdays = items }
        } catch {
            await MainActor.run { birthdays = [] }
        }
    }

    func nextDate(_ month: Int, _ day: Int) -> Date {
        let cal = Calendar.current
        let now = Date()
        var comps = DateComponents(year: cal.component(.year, from: now), month: month, day: day)
        var date = cal.date(from: comps)!
        if cal.startOfDay(for: date) < cal.startOfDay(for: now) {
            comps.year! += 1
            date = cal.date(from: comps)!
        }
        return date
    }

    func daysUntilNext(_ month: Int, _ day: Int) -> Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.startOfDay(for: nextDate(month, day))
        return max(cal.dateComponents([.day], from: start, to: end).day ?? 0, 0)
    }

    func countdownString(_ month: Int, _ day: Int) -> String {
        let d = daysUntilNext(month, day)
        if d == 0 { return "Today 🎉" }
        if d == 1 { return "in 1 day" }
        return "in \(d) days"
    }

    func formattedMonthDay(_ month: Int, _ day: Int) -> String {
        let date = Calendar.current.date(from: DateComponents(year: 2000, month: month, day: day))!
        let df = DateFormatter(); df.dateFormat = "MMM d"
        return df.string(from: date)
    }
}

#Preview {
    ContentView()
}
