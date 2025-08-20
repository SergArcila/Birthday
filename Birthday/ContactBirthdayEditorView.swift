//
//  ContactBirthdayEditorView.swift
//  Birthday
//
//  Created by Sergio Arcila on 8/19/25.
//

import SwiftUI

struct ContactBirthdayEditorView: View {
    
    
    @Environment(\.dismiss) private var dismiss
    

    let contactId: String
    var onSaved: (() -> Void)?

    @State private var personName: String = ""
    @State private var month: Int = 1
    @State private var day: Int = 1
    @State private var yearText: String = ""
    @State private var errorText: String?

    @State private var confirmRemove = false
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                if !personName.isEmpty {
                    Section("Contact") { Text(personName).font(.headline) }
                }
                Section("Birthday") {
                    Picker("Month", selection: $month) { ForEach(1...12, id:\.self) { Text("\($0)") } }
                    Picker("Day", selection: $day) { ForEach(1...31, id:\.self) { Text("\($0)") } }
                    TextField("Year (optional)", text: $yearText).keyboardType(.numberPad)
                }
                if let err = errorText {
                    Section { Text(err).foregroundStyle(.red).font(.footnote) }
                }
                Section("Danger Zone") {
                    Button("Remove Birthday", role: .destructive) { confirmRemove = true }
                    Button("Delete Contact", role: .destructive) { confirmDelete = true }
                }
            }
            .navigationTitle("Edit Birthday")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(day < 1 || day > 31)
                }
            }
            .task { load() }
            .confirmationDialog("Remove birthday from this contact?", isPresented: $confirmRemove, titleVisibility: .visible) {
                Button("Remove Birthday", role: .destructive) { removeBirthday() }
                Button("Cancel", role: .cancel) { }
            }
            .confirmationDialog("Delete this contact from your phone?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete Contact", role: .destructive) { deleteContact() }
                Button("Cancel", role: .cancel) { }
            }
        }
    }

    private func load() {
        do {
            let lite = try ContactsProvider.fetchContactLite(by: contactId)
            personName = "\(lite.givenName) \(lite.familyName)".trimmingCharacters(in: .whitespaces)
            month = lite.month ?? 1
            day = lite.day ?? 1
            yearText = lite.year.map(String.init) ?? ""
        } catch {
            errorText = "Could not load contact."
        }
    }

    private func save() {
        do {
            try ContactsProvider.updateContactBirthday(identifier: contactId,
                                                       month: month, day: day, year: Int(yearText))
            onSaved?()
            dismiss()
        } catch {
            errorText = "Saving failed. This contact may be read-only."
        }
    }

    private func removeBirthday() {
        do {
            try ContactsProvider.removeBirthday(identifier: contactId)
            onSaved?()            // list reloads, contact disappears from app
            dismiss()
        } catch {
            errorText = "Could not remove birthday (read-only account?)."
        }
    }

    private func deleteContact() {
        do {
            try ContactsProvider.deleteContact(identifier: contactId)
            onSaved?()            // list reloads
            dismiss()
        } catch {
            errorText = "Deletion failed. Some accounts don’t allow deleting."
        }
    }
}
