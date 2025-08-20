//
//  ManualStore.swift
//  Birthday
//
//  Created by Sergio Arcila on 8/19/25.
//

import Foundation

struct ManualBirthday: Identifiable, Codable, Hashable {
    var id: UUID
    var firstName: String
    var lastName: String
    var month: Int
    var day: Int
    var year: Int?

    init(id: UUID = UUID(),
         firstName: String,
         lastName: String,
         month: Int,
         day: Int,
         year: Int? = nil) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.month = month
        self.day = day
        self.year = year
    }
}

enum ManualStore {
    private static let key = "manual_birthdays_v1"

    static func load() -> [ManualBirthday] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([ManualBirthday].self, from: data)) ?? []
    }

    static func save(_ items: [ManualBirthday]) {
        let data = try? JSONEncoder().encode(items)
        UserDefaults.standard.set(data, forKey: key)
    }

    static func add(_ item: ManualBirthday) {
        var items = load()
        items.append(item)
        save(items)
    }

    static func remove(id: UUID) {
        var items = load()
        if let idx = items.firstIndex(where: { $0.id == id }) {
            items.remove(at: idx)
            save(items)
        }
    }
    
    static func update(_ item: ManualBirthday) {
        var items = load()
        if let i = items.firstIndex(where: { $0.id == item.id }) {
            items[i] = item
            save(items)
        }
    }
}
