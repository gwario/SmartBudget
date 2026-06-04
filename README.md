# SmartBudget

SmartBudget is a sophisticated yet easy-to-use periodic budget tracker built with Flutter. It's designed for people who want to manage recurring allowances—whether daily, weekly, or monthly—with advanced features like carry-over, savings expiration, and intelligent regional formatting.

## 🚀 Key Features

- **Flexible Periodicities**: Set budgets that repeat every few minutes (debug only), hours (debug only), days, weeks, months, or years.
- **Intelligent Carry Over**: Automatically carry over your surplus or deficit to the next period.
- **Smart Expiration**: Define a limit on how many periods a positive surplus can be carried over. Don't lose track of long-term goals by letting your budget accumulate indefinitely.
- **Total Savings Tracking**: Automatically track money "saved" when carry-over surplus expires.
- **Localized Experience**:
    - **Smart Currency Detection**: Automatically detects your regional currency (e.g., EUR for Austria) even if your UI language is set to English.
    - **Custom Week Starts**: Respects regional standards (Monday vs. Sunday) with manual override options.
    - **Custom Date Formats**: Support for ISO, European, US, and German date styles.
- **Historical Analysis**: Deep-dive into each period's expenses with a detailed breakdown of where your carry-in came from (previous period vs. older periods).
- **Modern Android Support**: Fully compliant with Android 15 edge-to-edge requirements and Material design standards.

## 🛠 Tech Stack

- **Framework**: [Flutter](https://flutter.dev)
- **Database**: [SQLite (sqflite)](https://pub.dev/packages/sqflite) for robust local persistence.
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

## 🔧 Development Notes

- **Debug Options**: High-frequency periods (Minutes and Hours) are only available in **Debug** builds to facilitate testing of budget cycles.

## 📄 License

This project is private. (c) 2026
