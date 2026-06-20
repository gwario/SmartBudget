# Changelog

All notable changes to this project will be documented in this file.

## [1.3.0] - 2026-06-20

### Added
- **Expense Deletion**: Implement expense deletion via long-press in the budget detail view, including a confirmation dialog.
- **Database Persistence**: Add `deleteExpense` method to the database persistence layer.
- **Enhanced Carry-over Logic**: Implement carry-over limits and tracking for expired budget funds.
- **Savings Tracking**: Logic to expire positive carry-over balances after a configurable number of periods while ensuring negative balances (debt) persist.
- **Budget Calculation**: Update budget calculation logic to accurately track total expired funds and carry-over origins across historical periods.
- **UI Enhancements**:
    - Enhance budget detail view with a new summary header showing total spent, total savings (expired funds), and a breakdown of carry-over sources.
    - Improve per-period UI to display carry-in details and expiration amounts.
    - Restrict high-frequency periodicities (minutes and hours) to debug mode.
- **Settings & Timezone Awareness**:
    - Introduce `SettingsProvider` to manage user preferences for locale, currency, timezone, date format, and the first day of the week.
    - Add a `SettingsPage` UI to allow users to configure global preferences.
    - Migrate date and period calculations to be timezone-aware using the `timezone` library.
- **Localization**:
    - Add `flutter_localizations` dependency and configure supported locales.
    - Enhance currency detection to infer regional currencies from locale country codes.

### Fixed
- Fixed currency formatting in expense entry dialog to match budget-specific currency.
- Improved UI feedback and spacing for expense list items.
- Fixed budget validation to handle localized number formats correctly.

## [1.1.0] - 2026-06-04

### Added
- **Android 15 Support**: Implement edge-to-edge support in `MainActivity` using `WindowCompat` for Android 15 compliance.
- **SDK & Dependencies**: Update Flutter SDK to 3.6.0 and bump dependencies including `sqflite`, `shared_preferences`, and `timezone`.
- **Theme Refactoring**: Refactor Android `styles.xml` to use `Theme.AppCompat` parents for both light and dark themes.
- **Documentation**: Extensively rewrite `README.md` to document features, tech stack, and installation steps.
