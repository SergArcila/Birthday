//
//  ContactsProvider.swift
//  Birthday
//
//  Created by Sergio Arcila on 8/19/25.
//

import Foundation
import Contacts

struct ContactBirthday: Identifiable, Hashable {
    let id = UUID()              // row identity for SwiftUI
    let contactId: String        // CNContact.identifier (for editing)
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
                    contactId: c.identifier,
                    givenName: c.givenName,
                    familyName: c.familyName,
                    month: m, day: d, year: b.year
                ))
            }
        }
        return items
    }
}
struct ContactLite: Identifiable, Hashable {
    let id: String            // CNContact.identifier
    let givenName: String
    let familyName: String
    let month: Int?
    let day: Int?
    let year: Int?
}

extension ContactsProvider {
    static func searchContacts(matching name: String) async throws -> [ContactLite] {
        let q = name.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { return [] }

        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactBirthdayKey as CNKeyDescriptor
        ]
        let predicate = CNContact.predicateForContacts(matchingName: q)
        let results = try store.unifiedContacts(matching: predicate, keysToFetch: keys)

        return results.map { c in
            ContactLite(
                id: c.identifier,
                givenName: c.givenName,
                familyName: c.familyName,
                month: c.birthday?.month,
                day: c.birthday?.day,
                year: c.birthday?.year
            )
        }
    }

    static func fetchContactLite(by identifier: String) throws -> ContactLite {
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactBirthdayKey as CNKeyDescriptor
        ]
        let c = try store.unifiedContact(withIdentifier: identifier, keysToFetch: keys)
        return ContactLite(
            id: c.identifier,
            givenName: c.givenName,
            familyName: c.familyName,
            month: c.birthday?.month,
            day: c.birthday?.day,
            year: c.birthday?.year
        )
    }

    static func updateContactBirthday(identifier: String, month: Int, day: Int, year: Int?) throws {
        let keys: [CNKeyDescriptor] = [
            CNContactBirthdayKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor
        ]
        let contact = try store.unifiedContact(withIdentifier: identifier, keysToFetch: keys)
        let mutable = contact.mutableCopy() as! CNMutableContact
        mutable.birthday = DateComponents(year: year, month: month, day: day)

        let req = CNSaveRequest()
        req.update(mutable)
        try store.execute(req)
    }

    static func createContact(firstName: String, lastName: String, month: Int, day: Int, year: Int?) throws {
        let new = CNMutableContact()
        new.givenName = firstName.trimmingCharacters(in: .whitespaces)
        new.familyName = lastName.trimmingCharacters(in: .whitespaces)
        new.birthday = DateComponents(year: year, month: month, day: day)

        let req = CNSaveRequest()
        let containerId = store.defaultContainerIdentifier()
        req.add(new, toContainerWithIdentifier: containerId)
        try store.execute(req)
    }
}
