//
//  NewContactView.swift
//  Birthday
//
//  Created by Sergio Arcila on 8/19/25.
//

import SwiftUI

struct NewContactView: View {
    @Environment(\.dismiss) private var dismiss
    var onSaved: (() -> Void)?

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phone = ""
    @State private var month = 1
    @State private var day = 1
    @State private var yearText = ""
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("First name", text: $firstName)
                    TextField("Last name", text: $lastName)
                }
                Section("Phone (optional)") {
                    TextField("Mobile number", text: $phone).keyboardType(.phonePad)
                }
                Section("Birthday") {
                    Picker("Month", selection: $month) { ForEach(1...12, id:\.self) { Text("\($0)") } }
                    Picker("Day", selection: $day) { ForEach(1...31, id:\.self) { Text("\($0)") } }
                    TextField("Year (optional)", text: $yearText).keyboardType(.numberPad)
                }
                if let err = errorText {
                    Section { Text(err).foregroundStyle(.red).font(.footnote) }
                }
            }
            .navigationTitle("New Contact")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(firstName.trimmingCharacters(in: .whitespaces).isEmpty || day < 1 || day > 31)
                }
            }
        }
    }

    private func save() {
        do {
            try ContactsProvider.createContact(
                firstName: firstName, lastName: lastName,
                phone: phone.isEmpty ? nil : phone,
                month: month, day: day, year: Int(yearText)
            )
            onSaved?()
            dismiss()
        } catch {
            errorText = "Could not create contact."
        }
    }
}
