# HAUPokemon Final Project

Cloud-connected, location-based monster hunting app built with Flutter, PHP, and MySQL.

This repository contains:
- A Flutter mobile app (`hau_pokemon/`)
- A PHP API reference/deployment folder (`api/`)

## Overview

HAUPokemon is a location-aware game app where players can:
- Register/login and manage account details
- Detect nearby monsters on a map
- Catch monsters and store catches in inventory
- View Top Hunters leaderboard and inspect each hunter's caught monsters
- Administer monsters (add/edit/delete)
- Control and monitor server status from the app (EC2 toggle/status integration)

## Key Features

### Player Features
- Authentication (register/login/logout)
- Map-based detection with scanning/radar effect
- Monster catch flow with location-aware backend validation
- Inventory view (`player_inventory.php`)
- Leaderboard and hunter catch details (`leaderboard.php` + inventory lookup)
- Account profile update (name, username, optional password)

### Admin Features
- Add monster with map-based spawn placement
- Edit existing monsters
- Delete monsters
- Full-screen map picker for easier spawn-point placement

### UX and Theme
- Global Light/Dark theme toggle from the sidebar
- Polished dialogs, cards, placeholders, and form behavior
- Keyboard-friendly forms (tap/drag dismiss)

## Tech Stack

- Frontend: Flutter (Dart)
- Map/Location: `google_maps_flutter`, `geolocator`
- Networking: `http`
- Backend: PHP API endpoints
- Database: MySQL (tables such as `monsterstbl`, `monster_catchestbl`, `playerstbl`, `locationstbl`)
- Extras: `audioplayers`, `torch_light`, `shared_preferences`, `image_picker`

## Repository Structure

```
FinalProject/
	README.md
	hau_pokemon/              # Flutter app
		lib/
			screens/
			services/
			models/
			theme/
			utils/
		pubspec.yaml
	api/                      # PHP API scripts (reference/deployment source)
		catch_monster.php
		add_monster.php
		update_monster.php
		delete_monster.php
		get_monster.php
		leaderboard.php
		player_inventory.php
		login_player.php
		register_player.php
		update_player.php
```

## Prerequisites

- Flutter SDK (3.x recommended)
- Android Studio and/or VS Code Flutter tooling
- A reachable PHP backend host (local server, EC2, etc.)
- MySQL database configured for the API scripts

## Flutter Setup

1. Open terminal in `hau_pokemon/`
2. Install dependencies:

```bash
flutter pub get
```

3. Configure backend URLs in `hau_pokemon/lib/utils/constants.dart`
	 - `backendApiUrl`
	 - `lambdaStatusUrl`
	 - `lambdaToggleUrl`

4. Run app:

```bash
flutter run
```

## Backend Setup (PHP)

Deploy files in `api/` to your PHP-enabled web server.

At minimum, verify these routes are reachable:
- `add_monster.php`
- `get_monster.php`
- `update_monster.php`
- `delete_monster.php`
- `catch_monster.php`
- `player_inventory.php`
- `leaderboard.php`
- `login_player.php`
- `register_player.php`
- `update_player.php`

Important:
- Ensure DB credentials are configured in API config files (without committing secrets).
- Keep route naming consistent with app fallback logic in `ApiService`.

## Development Commands

From `hau_pokemon/`:

```bash
flutter analyze
flutter test
```

## Common Troubleshooting

- API unreachable/timeouts:
	- Verify `backendApiUrl` in `constants.dart`
	- Verify server is online and routes exist
	- If using private networking, confirm connectivity (e.g., Tailscale)

- Catch/leaderboard issues:
	- Confirm latest `catch_monster.php` and `leaderboard.php` are deployed
	- Confirm DB schema/columns match API assumptions

- UI changes not reflecting:
	- Do a full app restart (not only hot reload), especially for map/animation drawing changes

## Current Status

The app currently includes:
- Working monster CRUD integration
- Catch flow with selected-monster handling and hardware feedback
- Inventory and leaderboard views
- Profile management
- Sidebar theme toggle

## Contributors

- Seane Karl S. Garcia - Mobile App Lead Developer
- Adrian John C. Alfonso - Cloud Architect
- Laurenzo S. Centeno - Documentation
- John Michael Y. Supan - QA Lead

