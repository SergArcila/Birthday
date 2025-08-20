//
//  BirthdaysCalendarScreen.swift
//  Birthday
//
//  Created by Sergio Arcila on 8/19/25.
//

import SwiftUI
import FSCalendar

struct BirthdaysCalendarScreen: View {
    // Pass from ContentView
    let contacts: [ContactBirthday]
    let manual: [ManualBirthday]

    // Real selected date (current year)
    @State private var selectedDate: Date? = Calendar.autoupdatingCurrent.startOfDay(for: Date())

    // Build a map of birthdays keyed by *normalized* date (year 2000)
    private var eventsByDay: [Date: [String]] {
        let cal = Calendar.autoupdatingCurrent
        var dict: [Date: [String]] = [:]

        func add(_ name: String, _ month: Int, _ day: Int) {
            if let d = cal.date(from: DateComponents(year: 2000, month: month, day: day)) {
                let key = cal.startOfDay(for: d)
                dict[key, default: []].append(name)
            }
        }

        contacts.forEach {
            add("\($0.givenName) \($0.familyName)".trimmingCharacters(in: .whitespaces), $0.month, $0.day)
        }
        manual.forEach {
            add("\($0.firstName) \($0.lastName)".trimmingCharacters(in: .whitespaces), $0.month, $0.day)
        }
        return dict.mapValues { $0.sorted() }
    }

    // Set of normalized dates for FSCalendar event dots
    private var datesWithEvents: Set<Date> {
        Set(eventsByDay.keys)
    }

    // Helper: normalize any date to year 2000 for lookup in eventsByDay
    private func normalizedKey(for date: Date) -> Date {
        let cal = Calendar.autoupdatingCurrent
        let c = cal.dateComponents([.month, .day], from: date)
        return cal.date(from: DateComponents(year: 2000, month: c.month, day: c.day))!
    }

    var body: some View {
        VStack(spacing: 12) {
            // Calendar in a soft card (works in light/dark)
            FSCalendarWrapper(
                datesWithEvents: datesWithEvents,
                selectedDate: $selectedDate
            )
            .frame(height: 360)
            .padding(.top, 8)
            .padding(.horizontal)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
            .padding(.horizontal)
            // Day details (THIS IS INSIDE BODY)
            Group {
                if let sel = selectedDate {
                    let names = eventsByDay[normalizedKey(for: sel)] ?? []
                    if names.isEmpty {
                        ContentUnavailableView("No birthdays on this day", systemImage: "gift")
                    } else {
                        List(names, id: \.self) { Text($0) }
                    }
                } else {
                    ContentUnavailableView("No birthdays on this day", systemImage: "gift")
                }
            }
        }
        .navigationTitle("Calendar")
    }
}



// MARK: - FSCalendar -> SwiftUI wrapper (stable, no flicker)
import SwiftUI
import FSCalendar

struct FSCalendarWrapper: UIViewRepresentable {
    var datesWithEvents: Set<Date>       // normalized (year 2000)
    @Binding var selectedDate: Date?     // real date

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> FSCalendar {
        let cal = FSCalendar()
        cal.delegate = context.coordinator
        cal.dataSource = context.coordinator
        cal.scope = .month
        cal.allowsMultipleSelection = false

        configureAppearance(cal, trait: cal.traitCollection)// 👈 set colors once
        return cal
    }

    func updateUIView(_ uiView: FSCalendar, context: Context) {
        // Reload events only if they changed (prevents ghost taps)
        if context.coordinator.updateCachedEvents(with: datesWithEvents) {
            uiView.reloadData()
        }

        // 👇 Re-apply colors if Light/Dark changed
        if context.coordinator.style != uiView.traitCollection.userInterfaceStyle {
            configureAppearance(uiView, trait: uiView.traitCollection)
            context.coordinator.style = uiView.traitCollection.userInterfaceStyle
        }

        if let date = selectedDate {
            if !Calendar.autoupdatingCurrent.isDate(uiView.currentPage, equalTo: date, toGranularity: .month) {
                uiView.setCurrentPage(date, animated: false)
            }
            if uiView.selectedDate != date {
                uiView.select(date)
            }
        }
    }

    /// Centralized appearance that works in Light/Dark
    private func configureAppearance(_ cal: FSCalendar, trait: UITraitCollection) {
        cal.backgroundColor = .clear

        // Header / weekdays
        cal.appearance.headerDateFormat   = "MMMM yyyy"
        cal.appearance.headerTitleColor   = .label
        cal.appearance.weekdayTextColor   = .secondaryLabel

        // Day numbers
        cal.appearance.titleDefaultColor      = .label
        cal.appearance.titleWeekendColor      = .secondaryLabel
        cal.appearance.titlePlaceholderColor  = .tertiaryLabel   // other-month days

        // Today / selection
        cal.appearance.todayColor             = .systemGray5     // subtle circle in both modes
        cal.appearance.titleTodayColor        = .label
        cal.appearance.selectionColor         = .systemBlue      // filled circle
        cal.appearance.titleSelectionColor    = .white
        cal.appearance.todaySelectionColor    = .systemBlue      // today when selected

        // Event dots
        cal.appearance.eventDefaultColor      = .systemPink
        cal.appearance.eventSelectionColor    = .white
    }

    final class Coordinator: NSObject, FSCalendarDelegate, FSCalendarDataSource, FSCalendarDelegateAppearance {
        let parent: FSCalendarWrapper
        let cal = Calendar.autoupdatingCurrent
        var style: UIUserInterfaceStyle = .unspecified
        private var cachedHash: Int = 0

        init(_ parent: FSCalendarWrapper) { self.parent = parent }

        // Stable hash, so we reload only when needed
        func updateCachedEvents(with set: Set<Date>) -> Bool {
            var hasher = Hasher()
            set.sorted().forEach { hasher.combine($0.timeIntervalSinceReferenceDate) }
            let newHash = hasher.finalize()
            let changed = (newHash != cachedHash)
            cachedHash = newHash
            return changed
        }

        // Dots: normalize only for lookup
        func calendar(_ calendar: FSCalendar, numberOfEventsFor date: Date) -> Int {
            let key = normalize(date)
            return parent.datesWithEvents.contains(key) ? 1 : 0
        }

        func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
            if monthPosition != .current { calendar.setCurrentPage(date, animated: true) }
            parent.selectedDate = cal.startOfDay(for: date)
        }

        private func normalize(_ date: Date) -> Date {
            let c = cal.dateComponents([.month, .day], from: date)
            return cal.date(from: DateComponents(year: 2000, month: c.month, day: c.day))!
        }
    }
}


