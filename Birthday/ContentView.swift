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
    // Data sources
    @State private var contacts: [ContactBirthday] = []
    @State private var manual: [ManualBirthday] = []

    // UI
    @State private var isLoading = false
    @State private var showAccessAlert = false
    @State private var showAddManual = false

    var body: some View {
        NavigationStack {
            List {
                if mergedSorted.isEmpty {
                    ContentUnavailableView(
                        "No birthdays yet",
                        systemImage: "gift",
                        description: Text("Add manually or allow Contacts access to see birthdays.")
                    )
                } else {
                    ForEach(mergedSorted) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.fullName)
                                    .font(.headline)
                                Text("\(formattedMonthDay(item.month, item.day)) · \(countdownString(item.month, item.day))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if item.source == .manual {
                                Text("Manual")
                                    .font(.caption2)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(.quaternary)
                                    .clipShape(Capsule())
                            } else {
                                Text("🎂")
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if item.source == .manual, let manualId = item.manualId {
                                Button(role: .destructive) {
                                    deleteManual(manualId)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Birthdays")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showAddManual = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add manually")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await reloadAll() } } label: { Image(systemName: "arrow.clockwise") }
                        .accessibilityLabel("Refresh")
                }
            }
        }
        .sheet(isPresented: $showAddManual) {
            AddManualBirthdayView {
                loadManual()
            }
        }
        .task { await reloadAll() }
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

    // MARK: - Merging

    enum Source { case contact, manual }

    struct RowItem: Identifiable, Hashable {
        var id: UUID
        var fullName: String
        var month: Int
        var day: Int
        var year: Int?
        var source: Source
        var manualId: UUID? // for deletions
    }

    var merged: [RowItem] {
        let contactRows = contacts.map { c in
            RowItem(
                id: c.id, fullName: "\(c.givenName) \(c.familyName)".trimmingCharacters(in: .whitespaces),
                month: c.month, day: c.day, year: c.year,
                source: .contact, manualId: nil
            )
        }
        let manualRows = manual.map { m in
            RowItem(
                id: m.id, fullName: "\(m.firstName) \(m.lastName)".trimmingCharacters(in: .whitespaces),
                month: m.month, day: m.day, year: m.year,
                source: .manual, manualId: m.id
            )
        }
        return contactRows + manualRows
    }

    var mergedSorted: [RowItem] {
        merged.sorted { nextDate($0.month, $0.day) < nextDate($1.month, $1.day) }
    }

    // MARK: - Loading

    func reloadAll() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        loadManual()

        do {
            let granted = try await ContactsProvider.requestAccess()
            if !granted {
                showAccessAlert = true
                contacts = []
                return
            }
            let items = try await ContactsProvider.fetchBirthdays()
            await MainActor.run { contacts = items }
        } catch {
            await MainActor.run { contacts = [] }
        }
    }

    func loadManual() {
        manual = ManualStore.load()
    }

    func deleteManual(_ id: UUID) {
        ManualStore.remove(id: id)
        loadManual()
    }

    // MARK: - Date helpers (same logic you had)

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
