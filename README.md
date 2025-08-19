# Birthday (iOS)

A tiny SwiftUI app that reads birthdays from your iPhone Contacts and shows an upcoming list **sorted by next occurrence** with a friendly **countdown** (e.g., “in 7 days” / “Today 🎉”). No accounts, no server—everything stays on your device.

**Repository:** https://github.com/SergArcila/Birthday

---

## Features (MVP)
- 📇 Requests Contacts permission and **reads birthdays** (month/day[/year])
- 🗓️ **Sorted by next occurrence** (wraps to next year automatically)
- ⏳ **Countdown**: “in X days”, “in 1 day”, “Today 🎉”
- 🔄 Refresh button
- 🛡️ **Privacy-first**: no networking, no analytics

## Requirements
- Xcode 15+
- iOS 17+ (runs best on device; the Simulator usually has no contacts)
- A few contacts with birthdays set (Contacts app → Edit → Birthday)

## Permissions
The app requests access to Contacts at runtime. Ensure this key is present under the target’s **Info** tab:

- **Privacy – Contacts Usage Description**  
  `We read birthdays from your Contacts to show reminders.`

## Getting Started
1. Open the project in Xcode and select your iPhone as the run target.
2. Run the app and tap **Allow** when asked for Contacts access.
3. If the list is empty, add birthdays to a couple contacts, then tap the **refresh** (↻) button.

## Project Structure
```
Birthday/
├─ BirthdayApp.swift          # App entry (SwiftUI)
├─ ContentView.swift          # UI: list, sorting, countdown
├─ ContactsProvider.swift     # Contacts access & birthday fetch
└─ Assets.xcassets
```

## How it works
- **ContactsProvider** fetches `CNContact`s with: given name, family name, and birthday.
- **ContentView**:
  - Calls `requestAccess()` then `fetchBirthdays()` on launch/refresh.
  - Computes the **next upcoming date** for each contact (this year or next).
  - Sorts by that date and renders a list with a **countdown** label.

_No SwiftData/CoreData; keeping the base simple and stable._

## Roadmap
- 🔔 Local notifications (daily reminder; “today’s birthdays”)
- ➕ Manual entries (for people not in Contacts)
- ✍️ AI birthday message generator + one‑tap send via Messages
- 🧩 Lock Screen/Home widgets
- ☁️ Optional iCloud sync (if we add manual entries)
- 🌐 Localization (EN/ES first)
- 📤 Export .ics Birthday calendar

## Privacy
- All data is read from the local Contacts database.
- No network calls.
- No analytics or third‑party SDKs.

## Troubleshooting
- **Empty list on Simulator**: the Simulator rarely has contacts. Test on a real device.
- **Didn’t see the permission prompt**: Settings → *Privacy & Security ▸ Contacts* → enable for “Birthday”.
- **List still empty**: ensure contacts actually have **Birthday** fields set.

---

## .gitignore (suggested)
```
# macOS
.DS_Store

# Xcode
build/
DerivedData/
*.xcuserstate
*.xccheckout
*.xcscmblueprint
*.xcworkspace/xcuserdata/
*.xcodeproj/project.xcworkspace/xcuserdata/
xcuserdata/

# SwiftPM
.swiftpm/
.build/

# Logs & symbols
*.log
*.dSYM
```

## Git Setup & Push

### Initialize (if not already)
```bash
git init
git branch -m main
```

### Add and commit
```bash
git add .
git commit -m "feat: MVP – contacts birthdays list with countdown"
```

### Add the GitHub remote (pick one)
**SSH (recommended)**
```bash
git remote add origin git@github.com:SergArcila/Birthday.git
```

**HTTPS**
```bash
git remote add origin https://github.com/SergArcila/Birthday.git
```

### Push
```bash
git push -u origin main
```

### Optional: tag this baseline
```bash
git tag -a v0.1.0 -m "MVP baseline"
git push origin v0.1.0
```

## License
MIT – do whatever you want, just don’t hold me liable.
