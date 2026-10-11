# SLA Task Tracker

A mobile project and SLA task tracker for small software development teams, built with Flutter. Teams can create tasks, assign them to teammates or post them to an open pool, track progress, and see at a glance which tasks are on track, at risk, or overdue.

> **Group 36** · Formative Assignment 1 · Mobile Application Development

---

## Table of Contents

- [Features](#features)
- [SLA Status Rules](#sla-status-rules)
- [Roles and Permissions](#roles-and-permissions)
- [Screens](#screens)
- [Tech Stack and Design Decisions](#tech-stack-and-design-decisions)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Demo Accounts](#demo-accounts)
- [Validation and Error Handling](#validation-and-error-handling)
- [Team and Contributions](#team-and-contributions)
- [AI Use Disclosure](#ai-use-disclosure)

---

## Features

- **Username and password login**, with one account per team member and a persistent session.
- **Team-based workspaces.** Each team only sees its own tasks.
- **Two ways to assign work.** A captain can assign a task directly to a teammate, or post it to an open pool for the team to pick up.
- **Automatic SLA classification** (On Track, At Risk, Overdue, Completed), calculated from each task's deadline, priority, and status.
- **Project dashboard** with an overall progress bar, SLA counters, and a "Needs attention" list.
- **Filtering** by ownership (All, Mine, Open pool) and by SLA status.
- **Full task lifecycle:** create, edit, delete, claim, and update status.
- **Local persistence.** Data survives closing and reopening the app.
- **Seeded demo data** with 3 teams, so the app is populated from the first launch.

## SLA Status Rules

Every task is classified automatically each time it is displayed (`Task.sla` in `lib/models/task.dart`):

| Order | Condition | Status |
|:-----:|-----------|--------|
| 1 | Task status is **Done** | **Completed** |
| 2 | Deadline has already passed | **Overdue** |
| 3 | Due within **48 hours** (or **72 hours** for High priority) | **At Risk** |
| 4 | Anything else | **On Track** |

High-priority tasks get a wider warning window because they have less room for delay.

## Roles and Permissions

| Action | Captain | Team member |
|--------|:-------:|:-----------:|
| View team tasks and dashboard | ✅ | ✅ |
| Create a task (assign or post to pool) | ✅ | ❌ |
| Edit or delete a task | ✅ | ❌ |
| Pick up a task from the open pool | ✅ | ✅ |
| Update status of own tasks | ✅ | ✅ |
| Update status of any team task | ✅ | ❌ |

A task with no assignee (`assignee == null`) is considered part of the **open pool**.

## Screens

1. **Sign In:** username and password, with a demo-accounts helper.
2. **Dashboard:** progress, SLA counters, and urgent tasks.
3. **Task List:** scope and SLA filters.
4. **Task Details:** task info, claim button, and status updates.
5. **Create / Edit Task:** form with validation (captain only).
6. **Team / Profile:** team roster, personal stats, sign out, and demo data reset.

Navigation uses a Material 3 `NavigationBar` for the three main tabs and `Navigator.push` for details and forms.

## Tech Stack and Design Decisions

| Area | Choice | Why |
|------|--------|-----|
| Framework | Flutter (Material 3) | Cross-platform mobile UI |
| State management | `setState()` | Simple and sufficient for the app's scope. State lives in `HomeShell` and flows down to child screens via constructors and callbacks. |
| Local storage | `shared_preferences` | The data set is small and has no complex queries, so tasks are stored as JSON. All storage code lives in one file, `storage.dart`. |
| Authentication | Local, hard-coded accounts | No backend is required, and this keeps the focus on the Flutter UI and flow. |

## Project Structure

```
lib/
├── main.dart                     # App entry point, theme, session check
├── models/
│   ├── member.dart               # Member (username, team, captain flag)
│   └── task.dart                 # Task model, enums, SLA logic, JSON
├── services/
│   ├── storage.dart              # SharedPreferences read/write
│   └── seed_data.dart            # Demo teams, accounts, and starter tasks
├── widgets/
│   └── task_card.dart            # Reusable TaskCard and SlaChip
└── screens/
    ├── sign_in_screen.dart
    ├── home_shell.dart           # App state + bottom navigation
    ├── dashboard_screen.dart
    ├── task_list_screen.dart
    ├── task_details_screen.dart
    ├── task_form_screen.dart
    └── team_screen.dart
```

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel)
- Android Studio or VS Code with an Android emulator, or a physical device

### Run the app

```bash
git clone <your-repository-url>
cd group_36_sla_tracker
flutter pub get
flutter run
```

Run it on an emulator or physical device, not in a browser.

## Demo Accounts

Passwords follow the pattern `username` + `123`.

| Team | Captain | Members |
|------|---------|---------|
| **Team Alpha** | `amara` | `jonas`, `lina`, `kofi`, `zara` |
| **Team Beta** | `daniel` | `mei`, `omar`, `sofia` |
| **Team Gamma** | `priya` | `lucas`, `fatima`, `noah`, `ella` |

Example: `amara` / `amara123`.

**Suggested walkthrough**
1. Sign in as a captain and create a task, or post one to the team pool.
2. Sign out and sign in as a teammate from the same team.
3. Pick up the task from **Tasks → Open pool** and change its status.
4. Watch the SLA chip and dashboard update.

Deadlines in the demo data are relative to the first launch. Use **Team → Reset demo data** to regenerate them.

## Validation and Error Handling

- **Sign in:** username and password are required, the password has a minimum length, and invalid credentials show an error message.
- **Task form:** title is required (3+ characters), description is limited to 200 characters, an assignee is required unless the task is posted to the pool, and a deadline must be chosen.
- **Delete:** requires confirmation in a dialog.
- **Empty states:** friendly messages when a filtered list has no tasks.

## Team and Contributions

| Member | Branch | Main contributions |
|--------|--------|--------------------|
| _Name_ | `feature/...` | _e.g. models and storage_ |
| _Name_ | `feature/...` | _e.g. authentication and team screens_ |
| _Name_ | `feature/...` | _e.g. dashboard and task list_ |
| _Name_ | `feature/...` | _e.g. task details and form_ |

- **Contribution tracker:** _link here_
- **Demo video:** _link here_


*Built with Flutter for Formative Assignment 1.*
