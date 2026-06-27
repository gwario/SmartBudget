# Changelog

All notable changes to this project will be documented in this file.

## [Current]

- **Build Infrastructure**: 
    - Upgraded Gradle to 8.14.0, Android Gradle Plugin to 8.11.1, and Kotlin to 2.2.20 for better long-term support and Android 15 compatibility.
    - Migrated to Flutter's **Built-in Kotlin** to resolve deprecation warnings and ensure future compatibility.

## [1.4.0] - 2026-06-27

### Added
- **Waterfall View**: Introduced a new intuitive calculation flow as the primary budget summary interface.
- **Improved Financial Terminology**:
    - "Carry Over" is now **"Surplus from Past"** or **"Deficit from Past"**.
    - "Actual Budget" is now **"Available Now"**.
    - "Carry in" is now **"Rollover"**.
- **Savings Vault**: Rebranded "Total Savings" and "Expired funds" to the **"Savings Vault"** metaphor, framing saved budget as stashed capital.
- **Budget Editing**: Users can now edit the title of existing budget schedules.
- **Full Unit Expenses**: Streamlined expense entry by enforcing whole numbers (minimum 1 unit) and optimized the keyboard for rapid entry.
- **Summary Reorganization**: Added clear **"CURRENT"** and **"TOTALS"** separators in the detail header to distinguish between periodic math and historical performance.
- **Duration Tracking**: Explicitly display the total duration a budget schedule has been running.

### Changed
- **UI Refinement**: Reduced vertical spacing in the header and history list for a more compact, data-dense view.
- **Simplified History Headers**: Removed redundant visual dots and "prev/older" breakdowns in favor of clear window span labels (e.g., "Rollover from 3 periods").
- **Currency Formatting**: Defaulted all currency displays to 0 decimal places for a cleaner look.
- **Navigation Improvement**: Moved the budget deletion button to the AppBar for better safety and focus.

### Fixed
- Fixed calculation performance for long-running budgets using an optimized sliding window algorithm.
- Resolved compilation issues related to variable scoping in the detail view.

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
