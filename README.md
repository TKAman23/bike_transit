# Bike Transit

A Google Maps–style biking app for the Seattle area. It suggests mixed
bike + bus/light-rail routes ranked by a **speed-vs-strain** tradeoff you
control, estimates time from your own riding ability (and learns from your
rides), guides you live while en route, and tracks your stats.

Built with Flutter · Google Maps Platform · One Bus Away (Puget Sound) ·
Firebase Auth + Cloud Firestore.

---

## Contents

1. [Features](#features)
2. [Route generation (how routes are built and ranked)](#route-generation)
3. [Setup](#setup)
4. [Running](#running)
5. [Project structure](#project-structure)
6. [Cloud data (Firestore schema)](#cloud-data-firestore-schema)
7. [Known limitations](#known-limitations)

---

## Features

### Sign-in
- Email/password sign-in and registration, plus Google sign-in (Firebase Auth).
- "Forgot password" page that sends a Firebase reset email.
- Signed-in riders open straight onto the map on the next launch.

### Map screen
- Full-screen map centered on Seattle, with Google's default buttons (zoom,
  compass, my-location, toolbar) turned off so the map stays bare. Business
  points of interest are hidden, and there's a matching dark map style.
- **Search bar** at the top: a bicycle icon on the left and a hamburger menu on
  the right.
  - While you type, a dropdown shows:
    - what you typed (resolved as an address),
    - your **recent places** (synced to the cloud),
    - Google Places suggestions near Seattle.
  - When you're editing the departure, **Your location** is also offered.
  - The **hamburger menu** opens your **Profile** and has a working
    **Dark mode** switch.
- **Tap the map** to drop a destination pin; the app names it by reverse
  geocoding.
- **Long-press the map** to save a bike-parking spot.

### Bottom sheet
A draggable sheet with rounded corners. It never closes: its smallest size
always shows the control row and the divider. At full size it stops just below
the search bar.

- **Control row:**
  - A **Route / Options** switch fills the left half of the screen.
  - The right half holds two equal buttons:
    - **Location button**, which cycles: center on you → heading-up (map rotates
      with the device compass) → back to north-up, centered.
    - **Compass**, whose needle shows the current map rotation; tap it to face
      north.
- A thin divider sits below the row. Route and Options **slide** between each
  other.
- **Opening size:** new riders get Options at full height. Returning riders
  start at 40% height on Route.
- **Size changes automatically:** the sheet grows when you pick a place,
  shrinks to its minimum during navigation, and comes back afterwards.

### Route view
- **From / To** buttons show the current endpoints. Long names fade out instead
  of breaking the layout. Tapping one focuses the search bar, and your next pick
  goes into that field. A swap button reverses the trip.
- With no destination, a clear **"No destination selected"** message appears.
- Choosing a destination sets the departure to your current location (unless
  you chose a different start), switches to Route, grows the sheet, and plans
  routes.
- **Route cards**, best match first:
  - a thin colored accent on the left, the same color as that route's line on
    the map;
  - the estimated time and arrival time;
  - every section in order: 🚲 + distance for bike sections, the **real route
    number** (e.g. `49`, `1 Line`) in its color + distance for transit, joined
    by dots and short colored lines;
  - a summary line (climb, parking note, "Best match");
  - an **up-chevron with "Details"**;
  - a **right-chevron button that starts navigation**.
- **Tap a card** to expand it. The chevron turns down and a slightly darker
  detail area opens beneath it:
  - **Bike sections:** a mountain-outline icon, a terrain-outline elevation
    graph, and the lowest and highest elevation plus total climb.
  - **Transit sections:** the route number in a rounded colored box, plus the
    **stops with ride times between them**. Long stop lists keep the first and
    last stops and replace the middle with a **⋮ N stops** marker. Each section
    is labeled *live* (One Bus Away prediction) or *scheduled*.
  - Only one card is expanded at a time.
  - On the map, the expanded route draws bike sections in **light blue** and
    gives each bus or rail route its own color; all other routes turn gray.

### Live navigation
- **Starting a route:**
  - The sheet content **slides** over to the instructions and the sheet drops
    to its minimum size.
  - The search bar **fades out and hides**.
  - The map tilts and follows you.
- **Collapsed control row:** a **recenter** button on the far left, then
  **time remaining**, the **time until the next section**, and the **next
  step**.
- **Instruction list:**
  - A **back-arrow button** at the top left feeds a continuous **spine** down
    the side.
  - Each bike or transit section branches off the spine, and its steps hang off
    a **thinner line** beneath it.
  - Transit sections show the **actual route number**.
  - Bike steps are turns; transit steps are stops. The first and last steps of
    each section are slightly larger.
  - Long sections collapse their middle steps behind **⋮ N more** (tap it to
    expand).
  - Only the current step is enlarged and highlighted; the other steps fade
    back.
  - Finished sections collapse, so the current section stays at the top.
- **Live tracking:** GPS fixes are snapped to the route, the step advances
  automatically, the part you've already covered fades on the map, and your
  location dot moves in real time.
- **Ride recording:** while biking, the app records your speed, the road's
  incline (from the route's elevation profile) and moving time, grouped by
  incline. The ride is saved to the cloud when the trip ends. Future time
  estimates blend these recorded speeds into the model ("Times personalized from
  your recorded rides").
- **Ending a trip:** arriving saves the trip and returns to the home map. Going
  back early saves the partial ride (if longer than 100 m) and returns to the
  route list.

### Options view
- **Settings:**
  - biking speed
  - endurance (how far you ride comfortably)
  - elevation gain (avoid hills ↔ don't mind)
  - speed vs. strain (least effort ↔ fastest)
  - public transit on/off
  - units (mi/km)
  - saved bike-parking spots (add from search or by long-pressing the map,
    remove from the list)
- **New riders** start from sensible defaults: 18 km/h, 10 km endurance,
  balanced weighting, transit on, miles. **Returning riders** load their cloud
  values.
- **Changes apply immediately to the current session** and re-rank the
  suggestions. A banner says they're session-only and offers **Reset** or
  **Save as default**. Nothing is written to the cloud unless you choose save,
  and each new session starts from your saved values.

### Profile
- Name or email and member-since date.
- **Statistics:**
  - distance biked
  - **estimated CO₂ saved** (the assumption is shown)
  - number of trips
  - moving time
  - average speed
  - total climb
  - distance by transit
- A **bar chart of the last 7 days**, and **recent trips**.
- **Reset password**, which sends an email to email/password accounts; Google
  accounts are told their password is managed by Google.
- Dark-mode switch and sign out.

### App icon & splash
- The app icon and the startup splash screen use the app's logo: a white rider
  on a bike over the brand blue-to-teal gradient, the same design as the
  in-app logo on the sign-in pages.
- The splash background matches the app theme: light `#F4F7FB` or dark
  `#0F161D`. Android 12+ uses the system splash API with the same logo.
- To regenerate after changing the design:

  ```bash
  flutter test tool/generate_brand_assets_test.dart   # renders assets/branding/*.png
  dart run flutter_launcher_icons                      # Android / iOS / web icons
  dart run flutter_native_splash:create                # native splash screens
  ```

### Themes & motion
- Light and dark themes come from one recipe, so the map, sheet, sign-in pages
  and profile all match. The map's own style switches with the theme.
- Animated theme changes, fade-forward page transitions, staggered entrance
  animations on the profile and sign-in pages, and animated cards, chevrons,
  sheet sizes and segment changes.

---

## Route generation

The spec called for routes built from **Google Maps + One Bus Away (OBA)**.
There is no personal OBA key yet, so the app is designed so **Google provides
all the routing** and OBA only adds real-time information on top:

1. **Google Routes API**, on its own, can already plan transit itineraries with
   real route numbers, boarding and alighting stops, departure times and stop
   counts. Every route works without OBA.
2. **One Bus Away** (Puget Sound) adds **live departure predictions** and the
   **full list of intermediate stops with times**. The app uses OBA's public
   development key `TEST`, which works but is rate-limited. Calls are made
   one at a time, retried once, and are optional: if OBA is unavailable or
   can't match a trip, the route keeps Google's schedule and the route list
   says so. A personal OBA key goes into `config/keys.json` with no code
   changes.

Google can't return a single bike-plus-transit route, so the app stitches
candidates together:

| Candidate | How it's built |
|---|---|
| **Bike only** | Google `BICYCLE` with alternatives. |
| **Transit, by bike** | Google `TRANSIT` with alternatives. Each walking part becomes a bike section; parts of 250 m or more are re-routed with `BICYCLE`. Your bike rides along (King County Metro buses have racks; Link light rail allows bikes). |
| **Bike to a better line** | Places Nearby Search finds up to 2 rail/transit **hubs** at least 800 m away, within your biking range (½ your endurance, max 5 km) and in the direction of travel. You bike to the hub, then take `TRANSIT` from there. |
| **Park at destination** | If you saved a parking spot within 400 m of the destination, you bike there and walk the rest. |
| **Park & ride** | You bike to a saved spot within your endurance range, lock up, and ride transit *without* the bike (total walking ≤ 1.5 km). |

Routes with more than **2 transfers** are dropped, duplicates are merged, and
the **top 5** are shown. Each bike or walk section gets an elevation profile
from the **Elevation API**.

### Time and strain model

Each bike section is cut into pieces of about 100 m.

- **Speed** on each piece = your speed × grade factor × fatigue factor:
  - **Grade factor:** uphill `1 / (1 + 9·grade)`; downhill `1 + min(0.35, 4·|grade|)`.
  - **Fatigue factor:** once your total biking passes your endurance distance,
    speed drops gradually, by up to 25%.
  - **Personalization:** after you record rides, your measured speed on each
    incline range is blended in, counting for more the more you've ridden, up
    to 80%.
- **Transit time:** you're ready to board after a 2-minute bike-loading buffer
  (1 minute without a bike), then wait for the departure (OBA live time if
  known). If you'd arrive too late, the route assumes the next vehicle and adds
  15 minutes.
- **Strain** = flat km + climb ÷ 100 m × (1.5 − hill tolerance), multiplied
  once you're past your endurance distance. Walking adds 0.4 per km; transit
  adds nothing.
- **Score** (lower is better), where `w` is your speed-vs-strain setting.
  Strain is measured against your own endurance distance, so effort well
  within your ability costs little:

  ```
  score = w · time / fastestTime  +  (1 − w) · (1 + strain / enduranceKm)
  ```

### APIs used

| API | Used for |
|---|---|
| Maps SDK (Android/iOS/JS) | The map itself |
| Places API (New) | Autocomplete, place details, nearby transit hubs |
| Geocoding API | Typed addresses, naming dropped pins |
| Routes API (`computeRoutes`) | Bike, transit and walking routes |
| Elevation API | Terrain graphs, climb, strain, incline telemetry |
| OBA `stops-for-location`, `arrivals-and-departures-for-stop`, `trip-details` | Live departures and full stop lists |

---

## Setup

### 1. API keys

Keys never go in tracked files. Copy the example file and fill it in:

```bash
cp config/keys.example.json config/keys.json
```

```json
{
  "MAPS_API_KEY": "Google key for the Maps SDK and Firebase",
  "MAPS_SERVICES_KEY": "optional: Google key for Routes, Places (New), Geocoding, Elevation",
  "OBA_API_KEY": "TEST"
}
```

**Key restrictions.** The app calls Routes, Places, Geocoding and Elevation
directly from the phone, and those requests have no web referrer. **A key
limited to websites (HTTP referrers) is rejected** with "Requests from referer
<empty> are blocked", and routing and search stop working. Recommended setup:

| Key | Restrict to | Used for |
|---|---|---|
| `MAPS_API_KEY` | **Android apps** (package `com.example.bike_transit` + your SHA-1) and/or iOS bundle ID | Maps SDK, Firebase Auth/Firestore |
| `MAPS_SERVICES_KEY` | **API restrictions only** (Routes API, Places API (New), Geocoding API, Elevation API); no application restriction | Route planning, search, elevation |

Without `MAPS_SERVICES_KEY`, the app uses `MAPS_API_KEY` for everything; that
works only if that key has no application restriction.

`config/keys.json` is git-ignored, and each platform reads it from there:

- **Dart code:** `--dart-define-from-file=config/keys.json`. VS Code does this
  automatically through `.vscode/launch.json`.
- **Android:** `android/app/build.gradle.kts` puts the key into the manifest
  placeholder `${MAPS_API_KEY}`. It also generates the git-ignored
  `android/app/google-services.json` from `google-services.template.json`.
- **iOS:** create `ios/Flutter/Secrets.xcconfig` containing
  `MAPS_API_KEY=your-key` (git-ignored). `Info.plist` → `AppDelegate.swift`
  reads it.
- **Web:** the Maps JS script is added at startup from the build-time key.

Why the Firebase key is also replaced: the API keys in the generated Firebase
config (`firebase_options.dart` and the original `google-services.json`) have
**expired**. The app uses `MAPS_API_KEY` for Firebase instead. If you later run
`flutterfire configure` and get fresh keys, this override is harmless.

For a personal OBA key, email `oba_api_key@soundtransit.org` and replace
`TEST` with it.

### 2. Firebase / Firestore

- Firebase project: `project-52242ff7-f3b2-4a18-bde`.
- Firestore (Native mode) is created in **us-west1**.
- The security rules in `firestore.rules` let each signed-in user read and
  write only their own `users/{uid}` tree. To redeploy them:

  ```bash
  firebase deploy --only firestore:rules
  ```
- **Google sign-in on Android** also needs your debug/release SHA-1
  registered in the Firebase console (`google-services.json` currently has no
  OAuth client).

### 3. Location

Android location permissions are declared in the manifest, and iOS has
`NSLocationWhenInUseUsageDescription`. On an emulator, put the GPS in Seattle:

```bash
adb emu geo fix -122.3331 47.6097
```

---

## Running

```bash
flutter pub get
flutter analyze
flutter test
flutter run --dart-define-from-file=config/keys.json
```

In VS Code, just press **F5** (the "Bike Transit" launch config passes the keys).

---

## Project structure

```
lib/
  main.dart                     Firebase init, providers, routes
  constants/                    app_config (key names, base URLs), route_constants
                                (model numbers, colors, CO₂ factor), theme, map_styles
  models/                       Place, UserPreferences, RouteOption/RouteSection/
                                TransitInfo/NavStep/ElevationProfile, TripRecord/
                                RideTelemetry/GradeBucket, BikeParkingSpot, UserStats
  services/                     API + cloud code (never in widgets)
    directions_service.dart     Google Routes API
    places_service.dart         Places (New) + Geocoding
    elevation_service.dart      Elevation API
    one_bus_away_service.dart   OBA enrichment
    route_planner.dart          builds route candidates
    route_ranker.dart           time/strain model + ranking
    location_service.dart       GPS + compass
    user_repository.dart        Firestore access
    ride_telemetry_service.dart, stats_service.dart, theme_service.dart, auth_service.dart
  state/                        ChangeNotifier view models (provider)
    user_data_controller.dart   cloud prefs + session prefs, parking, places, trips
    map_screen_controller.dart  endpoints, active field, routes, selection, sheet targets
    navigation_controller.dart  live progress, steps, telemetry, trip record
  views/                        login, forgot_password, maps, bottom_view, profile
  widgets/                      search bar, control row, route view/card/parts,
                                options view, nav view, auth scaffold
test/                           geo, ranking/telemetry, navigation, widget tests
assets/branding/                logo PNGs for the launcher icon and splash
tool/                           generate_brand_assets_test.dart (renders the logo PNGs)
firestore.rules                 per-user security rules
```

---

## Cloud data (Firestore schema)

| Path | Fields |
|---|---|
| `users/{uid}` | `bikeSpeedKph`, `enduranceKm`, `hillTolerance` (0–1), `transitEnabled`, `units` (`imperial`/`metric`), `speedStrainWeight` (0–1), `createdAt` |
| `users/{uid}/bikeParking/{id}` | `name`, `lat`, `lng` |
| `users/{uid}/recentPlaces/{placeKey}` | `name`, `address`, `placeId`, `lat`, `lng`, `lastUsedAt` |
| `users/{uid}/trips/{id}` | `startedAt`, `endedAt`, `origin`, `destination`, `bikeDistanceM`, `transitDistanceM`, `durationS`, `sections`, `ride { movingTimeS, avgSpeedMps, climbM, gradeBuckets[{fromPct, meters, seconds}] }` |

A rider with no `users/{uid}` document is treated as a **new user**. Statistics
are calculated from `trips` rather than stored, and the dark-mode choice is
saved on the device only.

---

## Platform notes

- **Android** and **web** are tested; iOS configuration exists but is untested.
- **Web specifics:**
  - Elevation goes through the Maps JavaScript `ElevationService`, because the
    Elevation REST API doesn't allow browser (CORS) requests.
  - Your location and saved parking spots are drawn as colored dots, because
    web maps ignore marker colors.
  - Everything drawn over the map uses `pointer_interceptor`, so clicks don't
    fall through to the map.
  - Google sign-in uses Firebase's popup flow.

## Known limitations

- **Getting back on track:** if you leave the route, navigation keeps snapping
  you to the nearest point of the planned route; it doesn't re-plan.
- **OBA rate limits:** the shared `TEST` key may be throttled. When that
  happens, routes fall back to Google's schedule times and the route list says
  so.
- **Heading-up mode** needs a compass sensor. Emulators usually don't have one,
  and the app tells you so.
- **iOS** setup (the `Secrets.xcconfig` key path) is in place but untested,
  because development happens on Windows.
- **Google sign-in on web** is configured (client ID in `web/index.html`) but
  was not exercised end to end, because the popup needs a person to complete it.
