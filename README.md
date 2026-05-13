# AptiQuest: Dungeon of Placements

AptiQuest is a gamified aptitude training app built with Flutter and Dart. It blends quiz practice with RPG mechanics: players clear topic floors, fight monsters, earn XP/coins, unlock abilities, and challenge the final boss room.

## Tech Stack

- Flutter 3.x
- Dart 3.x
- SharedPreferences (local persistence)
- Layered module structure (screens/models/services/widgets)

## Implemented Features

- Splash and themed home experience
- Login and persistent player profile
- Dungeon floors (Quant, Reasoning, English) with lock/unlock/completed states
- Battle engine with:
	- HP bars for player and monster
	- 4-option MCQ combat
	- Correct hit (20), wrong penalty (10)
	- Streak critical hit (40)
	- Per-question timer
- Abilities:
	- 50-50
	- Shield (unlock at level 3)
	- Double Damage (unlock at level 5)
	- Time Freeze (unlock at level 7)
	- Revival (unlock at level 10)
- Boss room:
	- 30 mixed questions
	- Boss HP 300
	- Timed run
	- Topic-wise breakdown on result
- Result screen with detailed stats
- Analytics screen:
	- Topic accuracy bars
	- Weak-topic highlight
	- Recent battle history
- Leaderboard (Top 10 local scores)
- Settings (sound/music/difficulty toggles)
- Multiplayer competition mode:
	- Add multiple students to one match
	- Same question set for all participants
	- Per-question timer and auto scoring
	- Winner and ranked standings selection
- Online arena mode (Firebase-backed):
	- Create/join room by room code
	- Live player lobby with ready status
	- Shared synchronized question rounds
	- Automatic winner selection from live standings
	- Host controls: force next round / force finish

## Project Structure

```
lib/
	config/
		app_constants.dart
	data/
		questions.dart
	models/
		player.dart
		monster.dart
		question.dart
	screens/
		splash_screen.dart
		home_screen.dart
		login_screen.dart
		multiplayer_arena_screen.dart
		online_arena_screen.dart
		dungeon_map.dart
		battle_screen.dart
		boss_room.dart
		result_screen.dart
		leaderboard_screen.dart
		analytics_screen.dart
		settings_screen.dart
	services/
		storage_service.dart
		question_service.dart
		firebase_service.dart
	widgets/
		hp_bar.dart
		monster_card.dart
		option_card.dart
		ability_button.dart
```

## Run Locally

```bash
flutter pub get
flutter run
```

## Quality Checks

```bash
flutter analyze
flutter test
```

## Current Notes

- Firebase integration is scaffolded in service layer and can be connected in the next phase.
- Question bank can be expanded to 50+ questions per topic for final demo depth.

## Online Multiplayer Setup (Firebase)

Online room mode uses `firebase_core` + `cloud_firestore` + `firebase_auth`.

To enable it:

1. Create Firebase project in Firebase Console.
2. Add Android app (package id = your Flutter applicationId).
3. Download `google-services.json` and place it at:
	- `android/app/google-services.json`
4. Configure FlutterFire (`flutterfire configure`) for all target platforms.
5. Create Firestore database.
6. Deploy Firestore rules from `firestore.rules`.
7. Open app and use `ONLINE ARENA` from home screen.

### Auth Model

- App signs players in anonymously via Firebase Auth.
- Every student gets a unique Firebase `uid`.

### Firestore Data Design

Collection: `matches`

```json
{
	"matchId": "ABC123",
	"hostId": "firebase_uid",
	"status": "waiting | ongoing | finished",
	"topic": "quant",
	"questionCount": 10,
	"secondsPerQuestion": 20,
	"currentQuestion": 0,
	"questions": [1, 7, 12],
	"winnerNames": ["Sanket"],
	"createdAt": "serverTimestamp"
}
```

Subcollection: `matches/{matchId}/players`

```json
{
	"uid": "firebase_uid",
	"name": "Sanket",
	"score": 0,
	"currentQuestion": 0,
	"isFinished": false,
	"correct": 0,
	"wrong": 0,
	"ready": true
}
```

Without Firebase config, local multiplayer mode still works.

## Battle Animation Pipeline

The app uses a Flutter + Flame battle renderer across all platforms, including Android smartphones.

### Runtime Behavior

- Correct answers trigger combo-based player attacks, hit-stop, slash effects, and critical strikes.
- Wrong answers trigger enemy counterattacks with knockback and damage feedback.
- Boss battles use the same renderer with heavier combat pacing and larger HP pools.
- HP, score, question flow, and rewards remain controlled by Flutter game logic.

### Mobile Performance Notes

- Battle scenes use a single lightweight renderer (`ShadowGame`) to keep memory and startup costs lower on phones.
- Event and feedback overlays are pure Flutter widgets with simple transitions (`AnimatedSwitcher`) for responsive UX.
