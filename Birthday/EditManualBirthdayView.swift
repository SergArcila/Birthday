//
//  EditManualBirthdayView.swift
//  Birthday
//
//  Created by Sergio Arcila on 8/19/25.
//

import SwiftUI

struct EditManualBirthdayView: View {
    @Environment(\.dismiss) private var dismiss

    let item: ManualBirthday
    var onSaved: (() -> Void)?

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var month = 1
    @State private var day = 1
    @State private var yearText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("First name", text: $firstName)
                    TextField("Last name", text: $lastName)
                }
                Section("Birthday") {
                    Picker("Month", selection: $month) { ForEach(1...12, id:\.self) { Text("\($0)") } }
                    Picker("Day", selection: $day) { ForEach(1...31, id:\.self) { Text("\($0)") } }
                    TextField("Year (optional)", text: $yearText).keyboardType(.numberPad)
                }
            }
            .navigationTitle("Edit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(firstName.trimmingCharacters(in: .whitespaces).isEmpty || day < 1 || day > 31)
                }
            }
            .onAppear {
                firstName = item.firstName
                lastName  = item.lastName
                month     = item.month
                day       = item.day
                yearText  = item.year.map(String.init) ?? ""
            }
        }
    }

    private func save() {
        let updated = ManualBirthday(
            id: item.id,
            firstName: firstName,
            lastName: lastName,
            month: month,
            day: day,
            year: Int(yearText)
        )
        ManualStore.update(updated)
        onSaved?()
        dismiss()
    }
}
