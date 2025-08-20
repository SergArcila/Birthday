//
//  PersonNotesStore.swift
//  Birthday
//
//  Created by Sergio Arcila on 8/20/25.
//

import Foundation

enum PersonNotesStore {
    private static let storageKey = "personNotes.v1"  // [contactId: text]

    static func load(id: String) -> String {
        let dict = UserDefaults.standard.dictionary(forKey: storageKey) as? [String: String]
        return dict?[id] ?? ""
    }

    static func save(id: String, text: String) {
        var dict = (UserDefaults.standard.dictionary(forKey: storageKey) as? [String: String]) ?? [:]
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            dict.removeValue(forKey: id)
        } else {
            dict[id] = text
        }
        UserDefaults.standard.set(dict, forKey: storageKey)
    }
}
