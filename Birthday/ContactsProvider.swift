//
//  ContactsProvider.swift
//  Birthday
//
//  Created by Sergio Arcila on 8/19/25.
//

import Foundation
import Contacts

struct ContactBirthday: Identifiable, Hashable {
    let id = UUID()
    let givenName: String
    let familyName: String
    let month: Int
    let day: Int
    let year: Int?
}

enum ContactsProvider {
    private static let store = CNContactStore()

    static func requestAccess() async throws -> Bool {
        try await withCheckedThrowingContinuation { cont in
            store.requestAccess(for: .contacts) { granted, error in
                if let error = error { cont.resume(throwing: error) }
                else { cont.resume(returning: granted) }
            }
        }
    }

    static func fetchBirthdays() async throws -> [ContactBirthday] {
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactBirthdayKey as CNKeyDescriptor
        ]
        let request = CNContactFetchRequest(keysToFetch: keys)
        var items: [ContactBirthday] = []

        try store.enumerateContacts(with: request) { c, _ in
            if let b = c.birthday, let m = b.month, let d = b.day {
                items.append(ContactBirthday(
                    givenName: c.givenName,
                    familyName: c.familyName,
                    month: m, day: d, year: b.year
                ))
            }
        }
        return items
    }
}
