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
    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    private func nextOccurrenceYear(_ month: Int, _ day: Int) -> Int {
        let date = nextDate(month, day) // you already have nextDate(_:_:)
        return Calendar.current.component(.year, from: date)
    }
    // SEARCH
    @State private var searchText = ""

    // Next-up model (computed from your existing data)
    private struct NextUp {
        let days: Int
        let month: Int
        let day: Int
        let year: Int
        let names: [String]   // all people who share that next date
    }

    private func formattedWeekdayMonthDay(_ month: Int, _ day: Int, year: Int) -> String {
        let cal = Calendar.current
        let d = cal.date(from: DateComponents(year: year, month: month, day: day))!
        let df = DateFormatter()
        df.locale = .autoupdatingCurrent
        df.dateFormat = "EEE, MMM d"     // e.g. Sun, Aug 29
        return df.string(from: d) + (year != currentYear ? " \(year)" : "")
    }
    private var nextUp: NextUp? {
        guard !allItems.isEmpty else { return nil }
        // Find minimum days until next birthday
        let minDays = allItems.map { daysUntilNext($0.month, $0.day) }.min() ?? 0
        // Everyone who has that soonest day
        let soonest = allItems.filter { daysUntilNext($0.month, $0.day) == minDays }
        guard let sample = soonest.first else { return nil }
        let nxtDate = nextDate(sample.month, sample.day)
        let yr = Calendar.current.component(.year, from: nxtDate)
        return NextUp(
            days: minDays,
            month: sample.month,
            day: sample.day,
            year: yr,
            names: soonest.map(\.fullName).sorted()
        )
    }

    // Search results (case-insensitive) sorted by soonest
    private var searchResults: [RowItem] {
        guard !searchText.isEmpty else { return [] }
        let filtered = allItems.filter { $0.fullName.localizedCaseInsensitiveContains(searchText) }
        return filtered.sorted { daysUntilNext($0.month, $0.day) < daysUntilNext($1.month, $1.day) }
    }
    
    private func nextUpCard(_ n: NextUp) -> some View {
        let first = n.names.first ?? ""
        let more  = max(0, n.names.count - 1)
        let title = more == 0 ? first : "\(first) & \(more) more"
        let dateText = formattedWeekdayMonthDay(n.month, n.day, year: n.year)

        return ZStack(alignment: .topTrailing) {
            // Card content
            HStack(spacing: 14) {
                // LEFT: circular days badge with "day(s)" under the number
                ZStack {
                    Circle().fill(Color.accentColor.opacity(0.16))
                    VStack(spacing: -2) {
                        Text("\(n.days)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text(n.days == 1 ? "day" : "days")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(Color.accentColor)
                }
                .frame(width: 60, height: 60)

                // RIGHT: name + weekday+date
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                        Text(dateText).bold()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.35), lineWidth: 0.5)
            )

            // TOP-RIGHT: explicit label
            Text("NEXT BIRTHDAY")
                .font(.caption2).bold()
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                .foregroundStyle(Color.accentColor)
                .padding(10)
        }
        .listRowInsets(EdgeInsets(top: 10, leading: 0, bottom: 6, trailing: 0))
        .listRowBackground(Color.clear)
        // a11y
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Next birthday in \(n.days) \(n.days == 1 ? "day" : "days"): \(title) on \(dateText).")
    }
    

    /// Split the "coming up" group into this year vs. next year.
    private var upcomingSplit: (thisYear: [RowItem], nextYear: [RowItem]) {
        var thisYear: [RowItem] = []
        var nextYear: [RowItem] = []
        for item in groups.upcoming {
            if nextOccurrenceYear(item.month, item.day) == currentYear {
                thisYear.append(item)
            } else {
                nextYear.append(item)
            }
        }
        // keep your “soonest first” ordering
        let sorter: (RowItem, RowItem) -> Bool = { a, b in
            daysUntilNext(a.month, a.day) < daysUntilNext(b.month, b.day)
        }
        return (thisYear.sorted(by: sorter), nextYear.sorted(by: sorter))
    }

    private func yearHeader(_ year: Int) -> some View {
        Text(verbatim: String(year))
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
    }

    private var noTodayRow: some View {
        Text("No birthdays today :(")
            .font(.callout)
            .foregroundStyle(.primary)
    }
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
                }
                else {
                    // TODAY — big banner + rows
                    // TODAY — one section, consistent spacing with others
                    if !searchText.isEmpty {
                        Section {
                            if searchResults.isEmpty {
                                Text("No matches")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(searchResults) { row in rowView(row) }
                            }
                        } header: {
                            sectionHeader(title: "Search Results")
                        }
                    } else {
                        Section{
                            if !groups.today.isEmpty {
                                // 1) Banner (no header)
                                Section {
                                    todayBanner(count: groups.today.count)
                                        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 16))
                                        .listRowBackground(Color.clear)
                                }
                            }
                        }
                        Section{
                            if groups.today.isEmpty {
                                if let n = nextUp {
                                    nextUpCard(n)                 // 👈 Flighty-style countdown when none today
                                } else {
                                    noTodayRow                     // fallback if no data at all
                                }
                            }
                        }
                        Section {
                            if groups.today.isEmpty {
                                noTodayRow
                                
                                
                                // now inside the section ✅
                                // (no custom insets here; let List handle it)
                            } else {
                                ForEach(groups.today) { row in
                                    rowView(row)
                                }
                            }
                        } header: {
                            sectionHeader(title: "Today")
                        }
                        
                        // THIS WEEK (1–7 days) — separate section
                        if !groups.week.isEmpty {
                            Section {
                                ForEach(groups.week) { row in rowView(row) }
                            } header: {
                                sectionHeader(title: "This week")
                            }
                        }
                        
                        // COMING UP (8+ days), then next year
                        let split = upcomingSplit
                        if !split.thisYear.isEmpty {
                            Section {
                                ForEach(split.thisYear) { row in rowView(row) }
                            } header: {
                                sectionHeader(title: "Coming up")
                            }
                        }
                        if !split.nextYear.isEmpty {
                            Section {
                                ForEach(split.nextYear) { row in rowView(row) }
                            } header: {
                                yearHeader(currentYear + 1)
                            }
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
        .searchable(text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search birthdays")
        
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
        NavigationLink {
            if item.source == .contact, let cid = item.contactId {
                ContactDetailView(contactId: cid)             // 👈 new view below
            } else if item.source == .manual, let mid = item.manualId,
                      let m = manual.first(where: { $0.id == mid }) {
                ManualDetailView(item: m) {                   // 👈 new view below
                    // If edited, refresh list
                    loadManual()
                }
            } else {
                // Fallback – shouldn't happen
                Text(item.fullName)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.fullName).font(.headline)
                    Text("\(formattedMonthDay(item.month, item.day)) · \(countdownString(item.month, item.day))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("🎂")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if item.source == .manual, let manualId = item.manualId,
               let m = manual.first(where: { $0.id == manualId }) {

                Button { editingManual = m } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button(role: .destructive) { deleteManual(manualId) } label: {
                    Label("Delete", systemImage: "trash")
                }

            } else if item.source == .contact, let cid = item.contactId {
                Button { editingContact = ContactID(id: cid) } label: {
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
