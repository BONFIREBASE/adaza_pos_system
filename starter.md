# Adaza POS — running the app

## Demo mode (in-memory, no Firebase)
Auth uses the env login (password from `.env`, signs in as Owner).

```
flutter run -t lib/main_demo.dart -d web-server
```

---

## Production mode (real Firebase)

> Tooling is already installed: `firebase-tools` and `flutterfire_cli`.
> The deploy config (`firebase.json`, `firestore.rules`, `firestore.indexes.json`)
> is ready. You only need to sign into the correct Adaza Google account and link
> a project.

### 1. Sign into the Adaza Google account
```
firebase logout
firebase login
```

### 2. Create + link the Firebase project and generate keys
```
dart pub global run flutterfire_cli:flutterfire configure
```
Pick "Create a new project" (or select the Adaza project). This regenerates
`lib/firebase_options.dart` with real keys.

In the Firebase console:
- Authentication -> Sign-in method -> enable **Email/Password**
- Firestore Database -> **Create database** (production mode)

### 2. Create the first Owner account
1. Authentication -> Users -> **Add user** (your email + password).
2. Copy that user's **UID**.
3. Firestore -> Start collection **`users`** -> Document ID = the UID, fields:
   - `email` (string) = the owner's email
   - `role` (string) = `owner`

This bootstrap document is what grants access. Accounts without a `users`
document are denied (by design).

### 3. Deploy the security rules
```
firebase deploy --only firestore:rules
```
(or paste `firestore.rules` into Firestore -> Rules and Publish)

### 4. Run the production app
```
flutter run -t lib/main.dart -d web-server
```
Sign in with the Owner email/password. Roles for future staff are added by
creating their auth account + a `users/{uid}` doc with role `admin` or
`cashier`.

---

## Brave / browser note
`-d web-server` prints a localhost URL you open in any browser. To auto-launch
Brave with hot reload:
```
set CHROME_EXECUTABLE=C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe
flutter run -t lib/main.dart -d chrome
```
