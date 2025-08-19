//
//  AddManualBirthdayView.swift
//  Birthday
//
//  Created by Sergio Arcila on 8/19/25.
//

import SwiftUI

struct AddManualBirthdayView: View {
    @Environment(\.dismiss) private var dismiss

    var onSaved: (() -> Void)?

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var month = 1
    @State private var day = 1
    @State private var yearText = ""   // optional

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("First name", text: $firstName)
                    TextField("Last name", text: $lastName)
                }
                Section("Birthday") {
                    Picker("Month", selection: $month) { ForEach(1...12, id: \.self) { Text("\($0)") } }
                    Picker("Day", selection: $day) { ForEach(1...31, id: \.self) { Text("\($0)") } }
                    TextField("Year (optional)", text: $yearText)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Add Birthday")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(firstName.trimmingCharacters(in: .whitespaces).isEmpty || day < 1 || day > 31)
                }
            }
        }
    }

    private func save() {
        let year = Int(yearText)
        let item = ManualBirthday(firstName: firstName, lastName: lastName, month: month, day: day, year: year)
        ManualStore.add(item)
        onSaved?()
        dismiss()
    }
}
