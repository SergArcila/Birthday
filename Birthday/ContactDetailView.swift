import SwiftUI
import Contacts
import ContactsUI

struct ContactDetailView: View {
    let contactId: String

    @State private var contact: CNContact?
    @State private var error: String?
    @State private var showNativeCard = false
    @State private var notes: String = ""
    private struct SectionBlock<Content: View>: View {
        let title: String
        @ViewBuilder var content: Content
        init(_ title: String, @ViewBuilder content: () -> Content) {
            self.title = title
            self.content = content()
        }
        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.headline)
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    var body: some View {
        Group {
            if let c = contact {
                ScrollView {
                    VStack(spacing: 16) {
                        hero(for: c)
                        funFacts(for: c)
                        quickActions(for: c)
                        notesSection(for: c)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .background(Color(.systemGroupedBackground))
            } else if let e = error {
                ContentUnavailableView(
                    "Couldn’t load contact",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text(e)
                )
            } else {
                ProgressView().controlSize(.large)
            }
        }
        .navigationTitle("Contact")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if contact != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Open in Contacts") { showNativeCard = true }
                }
            }
        }
        .sheet(isPresented: $showNativeCard) {
            if let c = contact {
                ContactCardView(contact: c, allowsEditing: true)
            }
        }
        .task {
            do {
                let c = try ContactsProvider.fetchContactFull(by: contactId)
                contact = c
                notes = PersonNotesStore.load(id: contactId)
            } catch {
                self.error = error.localizedDescription
            }
        }
        .onDisappear {
            PersonNotesStore.save(id: contactId, text: notes)
        }
    }

    // MARK: - Hero

    @ViewBuilder
    private func hero(for c: CNContact) -> some View {
        let (m, d, y) = (c.birthday?.month, c.birthday?.day, c.birthday?.year)
        let name = fullName(c)

        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LinearGradient(colors: [
                        Color.blue.opacity(0.18), Color.indigo.opacity(0.12)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing))
                HStack(spacing: 16) {
                    avatar(for: c)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(name).font(.title2).bold().lineLimit(1)
                        if let m, let d {
                            let next = nextDate(m, d)
                            let days = daysUntil(from: Date(), to: next)
                            let year = Calendar.current.component(.year, from: next)
                            Text(formattedWeekdayMonthDay(month: m, day: d, year: year))
                                .font(.headline)
                            Text(days == 0 ? "Today 🎉" :
                                 "In \(days) \(days == 1 ? "day" : "days")" + (y != nil ? " · turns \(year - (y ?? year))" : ""))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("No birthday on file").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity)
            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        }
    }

    private func avatar(for c: CNContact) -> some View {
        Group {
            if c.imageDataAvailable, let data = c.thumbnailImageData, let img = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable().scaledToFit().foregroundStyle(.tertiary)
            }
        }
        .frame(width: 84, height: 84)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color(.separator), lineWidth: 0.5))
    }

    // MARK: - Fun facts

    @ViewBuilder
    private func funFacts(for c: CNContact) -> some View {
        let (m, d, y) = (c.birthday?.month, c.birthday?.day, c.birthday?.year)
        if m == nil && d == nil { EmptyView() } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("Fun Facts").font(.headline)
                HStack(spacing: 12) {
                    if let m, let d {
                        FactCard(title: "Zodiac", value: zodiacSign(month: m, day: d))
                        FactCard(title: "Weekday", value: weekdayName(month: m, day: d))
                        FactCard(title: "Birthstone", value: birthstoneName(month: m))
                    }
                    if let y, let m, let d {
                        let next = nextDate(m, d)
                        FactCard(title: "Turning", value: "\(Calendar.current.component(.year, from: next) - y)")
                    }
                }
            }
        }
    }

    private struct FactCard: View {
        var title: String; var value: String
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased()).font(.caption2).foregroundStyle(.secondary)
                Text(value).font(.subheadline).bold().lineLimit(1).minimumScaleFactor(0.8)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.35), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Quick actions

    @ViewBuilder
    private func quickActions(for c: CNContact) -> some View {
        Group {
            if !c.phoneNumbers.isEmpty || !c.emailAddresses.isEmpty {
                SectionBlock("Quick Actions") {
                    HStack(spacing: 12) {
                        if let num = c.phoneNumbers.first?.value.stringValue {
                            ActionChip(title: "Call",    system: "phone.fill")  { dial(num) }
                            ActionChip(title: "Text",    system: "message.fill") { text(num) }
                            ActionChip(title: "WhatsApp",system: "message.fill") { openWhatsApp(num) }
                        }
                        if let email = c.emailAddresses.first.map({ String($0.value) }) {
                            ActionChip(title: "Email", system: "envelope.fill") { mail(email) }
                        }

                        // FaceTime can use phone OR email. Prefer phone, fallback to email.
                        if let ft = faceTimeAddress(c) {
                            ActionChip(title: "FaceTime",   system: "video.fill") { faceTime(ft, audio: false) }
                            //ActionChip(title: "FT Audio",   system: "phone.fill") { faceTime(ft, audio: true) }
                        }

                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }


    private struct ActionChip: View {
        var title: String
        var system: String
        var action: () -> Void
        var body: some View {
            Button(action: action) {
                HStack(spacing: 6) {
                    Image(systemName: system)
                    Text(title)
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 10)
                .frame(height: 40)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(.separator).opacity(0.35), lineWidth: 0.5))
            }
        }
    }

    // MARK: - Notes / Gift ideas

    @ViewBuilder
    private func notesSection(for c: CNContact) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notes & Gift Ideas").font(.headline)
            TextEditor(text: $notes)
                .frame(minHeight: 120)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color(.separator).opacity(0.35), lineWidth: 0.5)
                )
                .scrollContentBackground(.hidden)
            HStack {
                Spacer()
                Button("Save") { PersonNotesStore.save(id: contactId, text: notes) }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Helpers

    private func fullName(_ c: CNContact) -> String {
        "\(c.givenName) \(c.familyName)".trimmingCharacters(in: .whitespaces)
    }

    private func nextDate(_ month: Int, _ day: Int) -> Date {
        var comps = Calendar.current.dateComponents([.year], from: Date())
        comps.month = month; comps.day = day
        var date = Calendar.current.date(from: comps)!
        if Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date()) {
            comps.year! += 1; date = Calendar.current.date(from: comps)!
        }
        return date
    }

    private func daysUntil(from: Date, to: Date) -> Int {
        let cal = Calendar.current
        return max(cal.dateComponents([.day], from: cal.startOfDay(for: from), to: cal.startOfDay(for: to)).day ?? 0, 0)
    }

    private func formattedWeekdayMonthDay(month: Int, day: Int, year: Int) -> String {
        let d = Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
        let df = DateFormatter(); df.locale = .autoupdatingCurrent; df.dateFormat = "EEE, MMM d"
        return df.string(from: d) + (year != Calendar.current.component(.year, from: Date()) ? " \(year)" : "")
    }

    private func dial(_ number: String) {
        if let url = URL(string: "tel://\(number.filter { $0.isNumber })") {
            UIApplication.shared.open(url)
        }
    }
    private func text(_ number: String) {
        if let url = URL(string: "sms:\(number.filter { $0.isNumber })") {
            UIApplication.shared.open(url)
        }
    }
    private func mail(_ address: String) {
        if let url = URL(string: "mailto:\(address)") {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Fun fact data

    private func weekdayName(month: Int, day: Int) -> String {
        let y = Calendar.current.component(.year, from: Date())
        let d = Calendar.current.date(from: DateComponents(year: y, month: month, day: day))!
        let df = DateFormatter(); df.dateFormat = "EEEE"
        return df.string(from: d)
    }

    private func zodiacSign(month: Int, day: Int) -> String {
        switch (month, day) {
        case (3, 21...31),  (4, 1...19):  return "♈︎ Aries"
        case (4, 20...30),  (5, 1...20):  return "♉︎ Taurus"
        case (5, 21...31),  (6, 1...20):  return "♊︎ Gemini"
        case (6, 21...30),  (7, 1...22):  return "♋︎ Cancer"
        case (7, 23...31),  (8, 1...22):  return "♌︎ Leo"
        case (8, 23...31),  (9, 1...22):  return "♍︎ Virgo"
        case (9, 23...30), (10, 1...22):  return "♎︎ Libra"
        case (10, 23...31), (11, 1...21): return "♏︎ Scorpio"
        case (11, 22...30), (12, 1...21): return "♐︎ Sagittarius"
        case (12, 22...31), (1, 1...19):  return "♑︎ Capricorn"
        case (1, 20...31),  (2, 1...18):  return "♒︎ Aquarius"
        default:                              return "♓︎ Pisces"   // (2,19)…(3,20)
        }
    }

    private func birthstoneName(month: Int) -> String {
        ["", "Garnet", "Amethyst", "Aquamarine", "Diamond", "Emerald", "Pearl",
         "Ruby", "Peridot", "Sapphire", "Opal", "Topaz", "Turquoise"][month]
    }
}

// Prefer phone; fall back to email for FaceTime
private func faceTimeAddress(_ c: CNContact) -> String? {
    if let num = c.phoneNumbers.first?.value.stringValue { return num }
    if let email = c.emailAddresses.first.map({ String($0.value) }) { return email }
    return nil
}

// Launch FaceTime (video or audio)
private func faceTime(_ address: String, audio: Bool = false) {
    let cleaned = address.trimmingCharacters(in: .whitespaces)
    let scheme = audio ? "facetime-audio" : "facetime"
    if let url = URL(string: "\(scheme)://\(cleaned.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? cleaned)"),
       UIApplication.shared.canOpenURL(url) {
        UIApplication.shared.open(url)
    }
}

// --- WhatsApp ---

// Best-effort E.164-ish number (keep + if present, otherwise just digits).
private func normalizedE164(_ raw: String) -> String {
    let hasPlus = raw.trimmingCharacters(in: .whitespaces).hasPrefix("+")
    let digits = raw.filter(\.isNumber)
    return hasPlus ? "+" + digits : digits
}

private func openWhatsApp(_ rawNumber: String) {
    let n = normalizedE164(rawNumber)

    // Try the app first
    if let appURL = URL(string: "whatsapp://send?phone=\(n)"),
       UIApplication.shared.canOpenURL(appURL) {
        UIApplication.shared.open(appURL)
        return
    }

    // Fallback: web deeplink (opens WhatsApp if installed, otherwise Safari)
    if let webURL = URL(string: "https://wa.me/\(n)") {
        UIApplication.shared.open(webURL)
    }
}

/// Apple’s native contact card
struct ContactCardView: UIViewControllerRepresentable {
    let contact: CNContact
    var allowsEditing: Bool = true

    func makeUIViewController(context: Context) -> CNContactViewController {
        let store = CNContactStore()

        // Ask ContactsUI what keys it requires
        let required = CNContactViewController.descriptorForRequiredKeys()

        // Try to refetch the same contact with those keys
        let full: CNContact
        if let c = try? store.unifiedContact(
            withIdentifier: contact.identifier,
            keysToFetch: [required]   // you can add more keys here if you want
        ) {
            full = c
        } else {
            full = contact  // fallback (should not happen)
        }

        let vc = CNContactViewController(for: full)
        vc.allowsEditing = allowsEditing
        vc.allowsActions  = true
        return vc
    }

    func updateUIViewController(_ uiViewController: CNContactViewController, context: Context) {}
}
