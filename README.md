# On Track — Project & SLA Task Tracker

An offline-first Flutter app for a small team (3–10 people) to plan work, assign
it, and see at a glance which tasks are **On Track**, **At Risk** or **Overdue**
against their deadlines. No backend: everything lives in a local SQLite database.

- Material 3, light and dark themes, teal identity (`#0F766E`)
- Local PIN sign-in, manager / member roles
- Dashboard, task list with search / filters / sort / swipe actions, task details,
  create / edit form with a live SLA preview, team, statistics, activity feed
- Phone and tablet layouts (two-column master/detail from 840 dp)

## How to run

```bash
flutter pub get
flutter run            # any Android / iOS device or emulator
flutter analyze        # expected: No issues found
flutter test           # expected: all tests passed
```

First launch seeds one project, five members and 14 tasks with dates relative to
"today". Demo accounts all use PIN **1234**; **Ali Hassan** is the manager.
*Settings → Reset demo data* restores the seed.

> Android builds need a JDK supported by your Gradle/AGP version (17 or 21 work;
> JDK 25 does not with Gradle 8.14). Use `flutter config --jdk-dir <path>` if the
> build fails with a bare version string such as `25.0.3`.

## Architecture

```
┌──────────────────────────── features/ (UI) ────────────────────────────┐
│ auth · dashboard · tasks · team · profile · statistics · activity       │
└───────────────▲─────────────────────────────────────────────────────────┘
                │ context.watch / read
┌───────────────┴──── state/ (provider, ChangeNotifier) ──────────────────┐
│ Session · Member · Task · Activity · Settings                           │
│ permission checks + optimistic updates + error → AppException           │
└───────────────▲─────────────────────────────────────────────────────────┘
                │
┌───────────────┴──── data/repositories ───────────────┐   ┌─ domain/ ────┐
│ Member · Task · Project · Activity                    │   │ sla_engine   │
│ every write + its activity row = one transaction      │   │ permissions  │
└───────────────▲───────────────────────────────────────┘   │ task_stats   │
                │                                           └──────────────┘
┌───────────────┴────────── sqflite (SQLite) ─────────────────────────────┐
│ members · projects · tasks · subtasks · activity   (+ indexes, FKs on)  │
└─────────────────────────────────────────────────────────────────────────┘
        shared_preferences: signed-in member id, theme mode only
```

Folders: `lib/core` (theme, router, shared widgets, utils), `lib/data` (models,
database, repositories), `lib/domain` (pure Dart rules), `lib/state`
(providers), `lib/features` (screens).

Key decisions:

- **SLA state is computed, never stored.** `TaskStatus` is what people set;
  `SlaState` is derived on every read by the pure function
  `evaluate(task, now, {subtasks})`, so it can never go stale.
- **All times are UTC** in the database; conversion to local happens only in
  the formatters.
- **Permissions are enforced twice**: hidden in the UI and re-checked in the
  providers.
- **Removing a member** reassigns the history they authored (`created_by`,
  activity actor) to the manager who removed them, because those columns are
  NOT NULL foreign keys. Their assigned tasks become unassigned.
- **PINs are stored as `SHA-256(memberId:pin)`**, never in plain text. This is
  adequate for a local convenience lock, not for a networked system.

## Why SQLite and not SharedPreferences?

The data is relational (projects → tasks → subtasks, members ↔ tasks, activity
referencing both) and is queried by filter, sort and aggregate. SQLite gives us
foreign keys, cascades, transactions (a task change and its activity entry
succeed or fail together), indexes and schema migrations (`onUpgrade`).
SharedPreferences is a flat key/value store with no queries or integrity, so it
is used only for tiny settings: the session and theme.

## SLA rules

Evaluated in order; the first match wins. Thresholds live in `SlaConfig`
(`lib/domain/sla/sla_engine.dart`) and the About screen renders from the same
constants.

| # | State | Condition |
|---|-------|-----------|
| 1 | **Completed** | Status is Done. The reason says whether it was early or late. |
| 2 | **Overdue** | Not done and now is after the due date. |
| 3a | **At Risk** | Time left is *less than* the priority window: Critical 72 h, High 48 h, Medium 24 h, Low 12 h. |
| 3b | **At Risk** | At least 50% of the time has passed and progress is more than 25 points behind elapsed time. |
| 3c | **At Risk** | Still To Do after 60% of the time has passed. |
| 3d | **At Risk** | Unassigned after 40% of the time has passed. |
| 4 | **On Track** | None of the above. |

Notes: the comparison in 3a is strict (exactly 48 h left on a High task is still
On Track). A zero-length window counts as fully elapsed. Progress is the manual
slider, or the share of done subtasks when a task has subtasks.

## Permissions

| Action | Manager | Member |
|---|---|---|
| Create tasks | yes | yes |
| Edit / change status or progress | any task | own created or assigned tasks |
| Assign to | anyone | themselves or nobody |
| Delete | any task | only tasks they created |
| Add / edit / remove members | yes | no |
| Edit own profile and PIN | yes | yes |

## Sign-in

Pick a member (or type an email), then enter the 4-digit PIN. Five wrong
attempts lock that member out for 30 seconds, with a visible countdown.

## Tests

`flutter test` runs (with an in-memory SQLite through `sqflite_common_ffi`):

- `sla_engine_test` — every rule, boundaries, priorities, edge cases
- `validators_test` — title / dates / name / email / PIN rules
- `task_repository_test` — CRUD, cascades, activity in the same transaction
- `task_form_widget_test` — validation errors, live SLA preview, save
- `task_provider_test`, `persistence_test`, `task_stats_and_activity_test`
- `app_flow_widget_test`, `screens_smoke_test` — every route at 360 dp with
  1.3× text, light/dark, both roles, tablet layout, gestures, edit flow

## Dependencies

`provider`, `go_router`, `sqflite`, `shared_preferences`, `fl_chart`, `intl`,
`uuid`, `crypto`, `path`; dev: `sqflite_common_ffi`. `cupertino_icons` was
removed as unused. No custom font is bundled (no extra assets); set
`fontFamily` in `lib/core/theme/app_theme.dart` to use one.

## Team contributions

| Member     | Area                                                        |
|------------|-------------------------------------------------------------|
| Ali Rashid | Data layer, migrations, seed, SLA engine, tests, statistics |
| Phillip    | auth and profile feature,                                   |
| Jesse      | Task list, details, form                                    |
| Cedrick    | Dashboard, team screens, theme                              |
