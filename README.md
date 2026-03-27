# APM — Study Planner

A focused study session planner built with Flutter and Firebase. APM lets you create timed study plans based on proven focus techniques, track your progress across sessions, and pick up exactly where you left off.

---

## TEAM - ITIID 4 - MOBILE APP'S DEVELOPMENT
- Diego Eduardo Velasco Basulto
- Ibarra Núñez Juan Carlos
- Lomeli Ulloa Gilberto
- Andrey Emiliano Mares Estrada


## Features

- **Adaptive study methods** — automatically selects Pomodoro (≤2h), 52/17 (≤5h), or Deep Work (>5h) based on your available time
- **Multiple concurrent sessions** — run up to 5 study plans simultaneously
- **Persistent progress** — sessions survive logout and app restarts, stored in Firestore
- **Timer controls** — start, pause (freezes time), resume, and reset individual blocks
- **Real-time sync** — plan state updates instantly across devices via Firestore streams
- **Secure by design** — each user can only read and write their own data

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) |
| Auth | Firebase Authentication (Email/Password) |
| Database | Cloud Firestore |
| Architecture | Widget-centric layered (MVC simplified) |

---

## Project Structure

```
lib/
├── main.dart                  # Entry point + MaterialApp + auth gate
├── constants/
│   └── theme.dart             # Color palette, spacing constants, buildTheme()
├── models/
│   └── plan.dart              # Plan model, fromDoc/toMap, buildPlan() algorithm
├── widgets/
│   ├── shared.dart            # SCard, Tap, PBtn, Orb, ActBtn, DeleteBtn
│   ├── plan_card.dart         # PlanCard with timer state machine
│   └── wave_painter.dart      # Animated wave background for login
└── screens/
    ├── login_screen.dart      # Login + register with glass card UI
    └── home_screen.dart       # Home, stats, input card, session list
```

---

## Study Methods

| Hours | Method | Focus | Break |
|---|---|---|---|
| 1–2h | Pomodoro | 25 min | 5 min |
| 3–5h | 52 / 17 | 52 min | 17 min |
| 6–12h | Deep Work | 90 min | 15 min |

The method is selected automatically based on the hours entered. Total blocks are calculated as `floor((hours × 60) / (focus + break))`.

---

## Firestore Data Model

All plans live in a single flat collection. Access is restricted by `uid` at the Security Rules level — no user can read or write another user's documents.

```
planes/{docId}
  uid:              String    # Firebase Auth UID — access key
  hours:            int
  method:           String    # "Pomodoro" | "52 / 17" | "Deep Work"
  studyMin:         int
  breakMin:         int
  totalBlocks:      int
  completedBlocks:  int       # incremented on each completed block
  createdAt:        int       # millisecondsSinceEpoch
```

### Security Rules

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /planes/{docId} {
      allow read: if request.auth != null
                  && resource.data.uid == request.auth.uid;
      allow create: if request.auth != null
                    && request.resource.data.uid == request.auth.uid;
      allow update, delete: if request.auth != null
                             && resource.data.uid == request.auth.uid;
    }
  }
}
```

---

### Why We Use Firebase

Firebase is used in APM to handle user authentication and store study plans in the cloud.  
With Cloud Firestore, each user can keep their progress (completed blocks, hours, and method) even after closing the app.  
It also provides real-time updates across devices and ensures that users can only access their own data, making the app secure and easier to implement.

---

## Getting Started

### Prerequisites

- Flutter SDK `>=3.0.0`
- A Firebase project with **Authentication** (Email/Password) and **Firestore** enabled

### Setup

1. Clone the repo

```bash
git clone https://github.com/your-username/gpa.git
cd gpa
```

2. Install dependencies

```bash
flutter pub get
```

3. Connect Firebase

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This generates `lib/firebase_options.dart` — already listed in `.gitignore`, never commit it.

4. Apply the Firestore Security Rules above in **Firebase Console → Firestore → Rules**

5. Run the app

```bash
flutter run
```

---

## Dependencies

```yaml
firebase_core: ^3.0.0
firebase_auth: ^5.0.0
cloud_firestore: ^5.0.0
```

---

## Notes

- `firebase_options.dart` is intentionally excluded from version control. Each developer must run `flutterfire configure` to generate their own.
- The `test/` directory can be deleted — the default `widget_test.dart` references `MyApp` which does not exist in this project.
- Timer state (seconds remaining, current phase) is local to each `PlanCard` widget and resets on hot restart. Block completion progress is always persisted in Firestore.
