//
//  AddBirthdaySheet.swift
//  Birthday
//
//  Created by Sergio Arcila on 8/19/25.
//

import SwiftUI

struct AddBirthdaySheet: View {
    enum Mode: String, CaseIterable { case contacts = "Contacts", newContact = "New Contact" }

    @Environment(\.dismiss) private var dismiss
    var onSaved: (() -> Void)?

    @State private var mode: Mode = .contacts
    @State private var searchText: String = ""
    @State private var results: [ContactLite] = []
    @State private var isSearching = false

    private struct ContactID: Identifiable { let id: String }
    @State private var editing: ContactID?

    var body: some View {
        NavigationStack {
            VStack {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if mode == .contacts { contactsPane } else { newContactPane }
            }
            .navigationTitle("Add Birthday")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .sheet(item: $editing) { id in
                ContactBirthdayEditorView(contactId: id.id) { onSaved?() }
            }
        }
    }

    // MARK: - Contacts mode
    var contactsPane: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Search contacts", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await runSearch() } }
                Button { Task { await runSearch() } } label: { Image(systemName: "magnifyingglass") }
                    .disabled(searchText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()

            if isSearching { ProgressView().padding(.top, 16) }

            List {
                if results.isEmpty && !isSearching && !searchText.isEmpty {
                    ContentUnavailableView("No matches",
                        systemImage: "person.crop.circle.badge.questionmark",
                        description: Text("Try a different name."))
                } else {
                    ForEach(results, id: \.id) { c in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(c.givenName) \(c.familyName)".trimmingCharacters(in: .whitespaces))
                                    .font(.headline)
                                Text(birthdaySummary(c))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(c.month == nil ? "Add" : "Edit") {
                                editing = .init(id: c.id)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Manual mode
    var newContactPane: some View {
        NewContactView {
            onSaved?()
            dismiss()
        }
        .navigationBarBackButtonHidden(true)
    }

    // Helpers
    func birthdaySummary(_ c: ContactLite) -> String {
        if let m = c.month, let d = c.day {
            if let y = c.year { return "Birthday: \(m)/\(d)/\(y)" }
            return "Birthday: \(m)/\(d)"
        }
        return "No birthday set"
    }

    @MainActor
    func runSearch() async {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { results = []; return }
        isSearching = true
        defer { isSearching = false }
        do {
            results = try await ContactsProvider.searchContacts(matching: q)
        } catch {
            results = []
        }
    }
}
