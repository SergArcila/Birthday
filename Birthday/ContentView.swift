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
    @State private var showAddSheet = false
    @State private var editingManual: ManualBirthday?
    private struct ContactID: Identifiable { let id: String }
    @State private var editingContact: ContactID?

    var body: some View {
        NavigationStack {
            List {
                if allItems.isEmpty {
                    ContentUnavailableView(
                        "No birthdays yet",
                        systemImage: "gift",
                        description: Text("Add from Contacts or manually to get started.")
                    )
                } else {
                    // TODAY — big banner + rows
                    if !groups.today.isEmpty {
                        // 1) Banner (no header)
                        Section {
                            todayBanner(count: groups.today.count)
                                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 16))
                                .listRowBackground(Color.clear)
                        }

                        // 2) Today's names with a header
                        Section {
                            ForEach(groups.today) { row in
                                rowView(row)
                            }
                        } header: {
                            sectionHeader(title: "Today")
                        }
                    }

                    // THIS WEEK (1–7 days)
                    if !groups.week.isEmpty {
                        Section {
                            ForEach(groups.week) { row in rowView(row) }
                        } header: {
                            sectionHeader(title: "This week")
                        }
                    }

                    // COMING UP (8+ days)
                    if !groups.upcoming.isEmpty {
                        Section {
                            ForEach(groups.upcoming) { row in rowView(row) }
                        } header: {
                            sectionHeader(title: "Coming up")
                        }
                    }
                }
            }
            .navigationTitle("Birthdays")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showAddSheet = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add birthday")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    NavigationLink {
                        // if you don't keep manual, pass []
                        BirthdaysCalendarScreen(contacts: contacts, manual: manual)
                    } label: { Image(systemName: "calendar") }

                    Button { Task { await reloadAll() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .refreshable { await reloadAll() }
        }
        .sheet(isPresented: $showAddSheet) {
            AddBirthdaySheet {
                Task { await reloadAll() }
            }
        }
        .sheet(item: $editingManual) { m in
            EditManualBirthdayView(item: m) {
                loadManual()
            }
        }

        .sheet(item: $editingContact) { id in
            ContactBirthdayEditorView(contactId: id.id) {
                Task { await reloadAll() }
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

    // MARK: - Row view

    @ViewBuilder
    private func rowView(_ item: RowItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.fullName).font(.headline)
                Text("\(formattedMonthDay(item.month, item.day)) · \(countdownString(item.month, item.day))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if item.source == .manual {
                Text("Manual")
                    .font(.caption2)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.gray.opacity(0.15))
                    .clipShape(Capsule())
            } else {
                Text("🎂")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if item.source == .manual, let manualId = item.manualId,
               let m = manual.first(where: { $0.id == manualId }) {

                Button {
                    editingManual = m
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    deleteManual(manualId)
                } label: {
                    Label("Delete", systemImage: "trash")
                }

            } else if item.source == .contact, let cid = item.contactId {
                Button {
                    editingContact = ContactID(id: cid)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
        }
    }

    // MARK: - Section headers & banner

    private func sectionHeader(title: String) -> some View {
        Text(title.uppercased())
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
    }

    private func todayBanner(count: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TODAY").font(.caption).bold().opacity(0.9)
            Text(count == 1 ? "You have 1 birthday 🎉" : "You have \(count) birthdays 🎉")
                .font(.title3).bold()
            Text("Don’t forget to send a message!")
                .font(.footnote).opacity(0.95)
        }
        .padding(16)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.pink.opacity(0.9), Color.orange.opacity(0.9)]),
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 6)
        .padding(.vertical, 4)
    }

    // MARK: - Merging & grouping

    enum Source { case contact, manual }

    struct RowItem: Identifiable, Hashable {
        var id: UUID
        var fullName: String
        var month: Int
        var day: Int
        var year: Int?
        var source: Source
        var manualId: UUID?      // for manual edit/delete
        var contactId: String?   // for Contacts edit
    }

    private var contactRows: [RowItem] {
        contacts.map { c in
            RowItem(
                id: c.id,
                fullName: "\(c.givenName) \(c.familyName)".trimmingCharacters(in: .whitespaces),
                month: c.month, day: c.day, year: c.year,
                source: .contact,
                manualId: nil,
                contactId: c.contactId   // 👈 add this
            )
        }
    }

    private var manualRows: [RowItem] {
        manual.map { m in
            RowItem(
                id: m.id,
                fullName: "\(m.firstName) \(m.lastName)".trimmingCharacters(in: .whitespaces),
                month: m.month, day: m.day, year: m.year,
                source: .manual,
                manualId: m.id,
                contactId: nil
            )
        }
    }

    private var allItems: [RowItem] { contactRows + manualRows }

    private var groups: (today: [RowItem], week: [RowItem], upcoming: [RowItem]) {
        var today: [RowItem] = []
        var week: [RowItem] = []
        var upcoming: [RowItem] = []
        for item in allItems {
            let d = daysUntilNext(item.month, item.day)
            if d == 0 { today.append(item) }
            else if d <= 7 { week.append(item) }
            else { upcoming.append(item) }
        }
        // sort each by “soonest”
        let sorter: (RowItem, RowItem) -> Bool = { a, b in
            daysUntilNext(a.month, a.day) < daysUntilNext(b.month, b.day)
        }
        return (today.sorted(by: sorter), week.sorted(by: sorter), upcoming.sorted(by: sorter))
    }

    // MARK: - Loading (same as before)

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

    func loadManual() { manual = ManualStore.load() }

    func deleteManual(_ id: UUID) {
        ManualStore.remove(id: id)
        loadManual()
    }

    // MARK: - Date helpers

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
