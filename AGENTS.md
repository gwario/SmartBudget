# AI Agent Guidelines

This document serves as a guide for AI agents assisting with the development of the SmartBudget project.

## 📝 Project Context

**SmartBudget** is a sophisticated periodic budget tracker designed for managing recurring allowances with advanced financial logic.

- **Description**: A sophisticated periodic budget tracker with intelligent carry-over, savings expiration, and localized formatting.
- **Core Logic**: The app calculates budget balances using a sliding window for carry-over surplus, while ensuring deficits (debt) never expire.

## 🤖 AI Instructions

When making updates or adding new features, agents **MUST** ensure the following files are updated accordingly:

1.  **`pubspec.yaml`**: 
    - Only change the `version` if code is actually changed.
    - Respect semantic versioning (Major.Minor.Patch).
    - Always increment the build number (the number after the `+`) in case of any code changes.
    - **The version bump should be performed in a separate commit.**
    - Ensure the `description` accurately reflects any major changes in scope.
2.  **`README.md`**: Update the "🚀 Key Features" or "🚀 Getting Started" sections if a new feature or dependency is added.
3.  **`CHANGELOG.md`**: 
    - Do **NOT** invent any changelog entries.
    - Look at the commit history to get the information for the changelog from there.
    - Add a new entry describing the changes, following the existing format (Added, Fixed, Changed, etc.).

## 🛠 Architectural Principles

- **Localization**: Always prefer using `SettingsProvider` for date, time, and currency formatting. Do not hardcode regional assumptions.
- **Persistence**: Database schema changes must include a version bump in `model.dart` and a corresponding migration in `database.dart`.
- **UI/UX**: Keep the detail summary header clean and consistent. Use sub-labels for secondary information.
- **Debugging**: Keep high-frequency testing units (minutes/hours) restricted to `kDebugMode`.
