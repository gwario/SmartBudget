# SmartBudget

SmartBudget is a sophisticated yet easy-to-use periodic budget tracker built with Flutter. It's designed for people who want to manage recurring allowances—whether daily, weekly, or monthly—with advanced features like surplus rollover, savings expiration, and intelligent regional formatting.

## 🚀 Key Features

- **Intuitive Budget Dashboard**: Visualize exactly how your available budget is calculated from your base allowance and past performance in a clear two-column summary.
- **Collapsible History**: Deep-dive into each period's expenses with a clean, expandable breakdown of rollover history and period-specific allowance.
- **Flexible Periodicities**: Set budgets that repeat every few minutes (debug only), hours (debug only), days, weeks, months, or years.
- **Intelligent Rollover**: Automatically carry over your surplus or deficit to the next period.
- **Savings Vault**: Define a limit on how many periods a positive surplus can be carried over. Expired surplus is moved to your "Vault," tracking your long-term savings achievements.
- **Localized Experience**:
    - **Smart Currency Detection**: Automatically detects your regional currency (e.g., EUR for Austria) even if your UI language is set to English.
    - **Custom Week Starts**: Respects regional standards (Monday vs. Sunday) with manual override options.
    - **Custom Date Formats**: Support for ISO, European, US, and German date styles.
- **Historical Analysis**: Deep-dive into each period's expenses with a clear breakdown of rollover history.
- **Modern Android Support**: Fully compliant with Android 15 edge-to-edge requirements and Material design standards.

## 🛠 Tech Stack

- **Framework**: [Flutter](https://flutter.dev)
- **Database**: [SQLite (sqflite)](https://pub.dev/packages/sqflite) for robust local persistence with an optimized sliding-window calculation engine.
- **State Management**: [Provider](https://pub.dev/packages/provider).
- **Background Tasks**: [Workmanager](https://pub.dev/packages/workmanager) for periodic balance calculations.
- **Localization**: [intl](https://pub.dev/packages/intl) and `flutter_localizations`.

## 📦 Getting Started

### Prerequisites
- Flutter SDK (version 3.6.0 or higher recommended)
- Android SDK (targeting API 35 for best experience)

### Installation
1. Clone the repository.
2. Run `flutter pub get` to fetch dependencies.
3. Run `flutter run` to start the app on your connected device.

## 🧪 Testing

The project includes unit tests for the core budget logic (rollover, timezone handling, periodicity).

- **Run all tests**: `flutter test`
- **Run specific test file**: `flutter test test/budget_logic_test.dart`

## 🔧 Development Notes

- **Debug Options**: High-frequency periods (Minutes and Hours) are only available in **Debug** builds to facilitate testing of budget cycles.
- **Edge-to-Edge**: The app uses modern `WindowCompat` APIs to ensure the UI flows correctly behind system bars on Android 15+ devices.

## 📄 License

See [LICENSE](LICENSE)
