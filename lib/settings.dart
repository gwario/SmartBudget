import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

class SettingsProvider with ChangeNotifier {
  static const String _localeKey = 'selected_locale';
  static const String _currencyKey = 'selected_currency';
  static const String _timezoneKey = 'selected_timezone';
  static const String _dateFormatKey = 'selected_date_format';
  static const String _firstDayOfWeekKey = 'first_day_of_week';

  String? _locale;
  String? _currency;
  String? _timezone;
  String? _dateFormat;
  int? _firstDayOfWeek;

  SettingsProvider() {
    _loadSettings();
  }

  String? get locale => _locale;

  String? get currency => _currency;

  String? get timezone => _timezone;

  String? get dateFormat => _dateFormat;

  int? get firstDayOfWeek => _firstDayOfWeek;

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _locale = prefs.getString(_localeKey);
    _currency = prefs.getString(_currencyKey);
    _timezone = prefs.getString(_timezoneKey);
    _dateFormat = prefs.getString(_dateFormatKey);
    _firstDayOfWeek = prefs.getInt(_firstDayOfWeekKey);
    notifyListeners();
  }

  Future<void> setLocale(String? newLocale) async {
    _locale = newLocale;
    final prefs = await SharedPreferences.getInstance();
    if (newLocale == null) {
      await prefs.remove(_localeKey);
    } else {
      await prefs.setString(_localeKey, newLocale);
    }
    notifyListeners();
  }

  Future<void> setCurrency(String? newCurrency) async {
    _currency = newCurrency;
    final prefs = await SharedPreferences.getInstance();
    if (newCurrency == null) {
      await prefs.remove(_currencyKey);
    } else {
      await prefs.setString(_currencyKey, newCurrency);
    }
    notifyListeners();
  }

  Future<void> setTimezone(String? newTimezone) async {
    _timezone = newTimezone;
    final prefs = await SharedPreferences.getInstance();
    if (newTimezone == null) {
      await prefs.remove(_timezoneKey);
    } else {
      await prefs.setString(_timezoneKey, newTimezone);
    }
    notifyListeners();
  }

  Future<void> setDateFormat(String? newDateFormat) async {
    _dateFormat = newDateFormat;
    final prefs = await SharedPreferences.getInstance();
    if (newDateFormat == null) {
      await prefs.remove(_dateFormatKey);
    } else {
      await prefs.setString(_dateFormatKey, newDateFormat);
    }
    notifyListeners();
  }

  Future<void> setFirstDayOfWeek(int? newDay) async {
    _firstDayOfWeek = newDay;
    final prefs = await SharedPreferences.getInstance();
    if (newDay == null) {
      await prefs.remove(_firstDayOfWeekKey);
    } else {
      await prefs.setInt(_firstDayOfWeekKey, newDay);
    }
    notifyListeners();
  }

  DateFormat getDateFormat({bool includeTime = false}) {
    if (_dateFormat != null) {
      return includeTime
          ? DateFormat("$_dateFormat HH:mm")
          : DateFormat(_dateFormat);
    }
    return includeTime ? DateFormat.yMd().add_Hm() : DateFormat.yMd();
  }

  DateFormat getTimeFormat() {
    return DateFormat.Hms();
  }

  DateTime toSelectedTimezone(DateTime dt) {
    final location = _timezone != null ? tz.getLocation(_timezone!) : tz.local;
    return tz.TZDateTime.from(dt, location);
  }

  String get systemCurrency {
    String locale = Platform.localeName;
    try {
      var format = NumberFormat.simpleCurrency(locale: locale);
      // If it's USD but we are not in the US, try to infer from country code
      if (format.currencyName == 'USD' &&
          !locale.contains('_US') &&
          !locale.contains('-US')) {
        if (locale.contains(RegExp(r'[_-]'))) {
          String country = locale.split(RegExp(r'[_-]')).last.toUpperCase();
          final countryToCurrency = {
            'AT': 'EUR',
            'BE': 'EUR',
            'CY': 'EUR',
            'EE': 'EUR',
            'FI': 'EUR',
            'FR': 'EUR',
            'DE': 'EUR',
            'GR': 'EUR',
            'IE': 'EUR',
            'IT': 'EUR',
            'LV': 'EUR',
            'LT': 'EUR',
            'LU': 'EUR',
            'MT': 'EUR',
            'NL': 'EUR',
            'PT': 'EUR',
            'SK': 'EUR',
            'SI': 'EUR',
            'ES': 'EUR',
            'HR': 'EUR',
            'GB': 'GBP',
            'CH': 'CHF',
          };
          if (countryToCurrency.containsKey(country)) {
            return countryToCurrency[country]!;
          }
        }
      }
      return format.currencyName ?? 'USD';
    } catch (_) {
      return 'USD';
    }
  }

  String get effectiveCurrency => _currency ?? systemCurrency;
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        children: const [
          _LocaleSetting(),
          _CurrencySetting(),
          _TimezoneSetting(),
          _DateFormatSetting(),
          _FirstDayOfWeekSetting(),
        ],
      ),
    );
  }
}

class _LocaleSetting extends StatelessWidget {
  const _LocaleSetting();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final systemLocale = Platform.localeName;
    final locales = {
      null: 'System Default ($systemLocale)',
      'en': 'English',
      'de': 'German',
      'es': 'Spanish',
      'fr': 'French',
      'it': 'Italian',
      'pt': 'Portuguese',
      'ru': 'Russian',
      'zh': 'Chinese',
      'ja': 'Japanese',
      'ko': 'Korean',
    };

    return ListTile(
      title: const Text('Language / Locale'),
      subtitle: Text(locales[settings.locale] ?? 'Unknown'),
      leading: const Icon(Icons.language),
      trailing: DropdownButton<String?>(
        value: settings.locale,
        underline: const SizedBox(),
        alignment: Alignment.centerRight,
        onChanged: settings.setLocale,
        items: locales.entries
            .map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value),
                ))
            .toList(),
      ),
    );
  }
}

class _CurrencySetting extends StatelessWidget {
  const _CurrencySetting();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final currencies = {
      null: 'System Default (${settings.systemCurrency})',
      'USD': 'US Dollar (\$)',
      'EUR': 'Euro (€)',
      'GBP': 'British Pound (£)',
      'JPY': 'Japanese Yen (¥)',
      'CHF': 'Swiss Franc (CHF)',
      'AUD': 'Australian Dollar (A\$)',
      'CAD': 'Canadian Dollar (C\$)',
      'CNY': 'Chinese Yuan (¥)',
      'INR': 'Indian Rupee (₹)',
      'BRL': 'Brazilian Real (R\$)',
    };

    return ListTile(
      title: const Text('Default Currency'),
      subtitle: Text(currencies[settings.currency] ?? 'Unknown'),
      leading: const Icon(Icons.monetization_on),
      trailing: DropdownButton<String?>(
        value: settings.currency,
        underline: const SizedBox(),
        alignment: Alignment.centerRight,
        onChanged: settings.setCurrency,
        items: currencies.entries
            .map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value),
                ))
            .toList(),
      ),
    );
  }
}

class _TimezoneSetting extends StatelessWidget {
  const _TimezoneSetting();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final systemTimezone = tz.local.name;
    final timezones = {
      null: 'System Default ($systemTimezone)',
      'UTC': 'UTC',
      'Europe/Berlin': 'Berlin / Central Europe',
      'Europe/London': 'London / GMT',
      'America/New_York': 'New York / Eastern',
      'America/Chicago': 'Chicago / Central',
      'America/Denver': 'Denver / Mountain',
      'America/Los_Angeles': 'Los Angeles / Pacific',
      'Asia/Tokyo': 'Tokyo / Japan',
      'Asia/Dubai': 'Dubai / Gulf',
      'Asia/Singapore': 'Singapore',
      'Australia/Sydney': 'Sydney / Australia',
    };

    return ListTile(
      title: const Text('Timezone'),
      subtitle: Text(timezones[settings.timezone] ?? 'Unknown'),
      leading: const Icon(Icons.access_time),
      trailing: DropdownButton<String?>(
        value: settings.timezone,
        underline: const SizedBox(),
        alignment: Alignment.centerRight,
        onChanged: settings.setTimezone,
        items: timezones.entries
            .map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value),
                ))
            .toList(),
      ),
    );
  }
}

class _DateFormatSetting extends StatelessWidget {
  const _DateFormatSetting();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final now = DateTime.now();
    final dateFormats = {
      null: 'System Default (${DateFormat.yMd().format(now)})',
      'yyyy-MM-dd': 'ISO (2024-12-31)',
      'dd/MM/yyyy': 'European (31/12/2024)',
      'MM/dd/yyyy': 'US (12/31/2024)',
      'dd.MM.yyyy': 'German (31.12.2024)',
    };

    return ListTile(
      title: const Text('Date Format'),
      subtitle: Text(dateFormats[settings.dateFormat] ?? 'Unknown'),
      leading: const Icon(Icons.calendar_today),
      trailing: DropdownButton<String?>(
        value: settings.dateFormat,
        underline: const SizedBox(),
        alignment: Alignment.centerRight,
        onChanged: settings.setDateFormat,
        items: dateFormats.entries
            .map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value),
                ))
            .toList(),
      ),
    );
  }
}

class _FirstDayOfWeekSetting extends StatelessWidget {
  const _FirstDayOfWeekSetting();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final firstDayIndex = MaterialLocalizations.of(context).firstDayOfWeekIndex;

    // Flutter index: 0 = Sunday, 1 = Monday, ..., 6 = Saturday
    // We want to map this to our 1 = Monday, ..., 7 = Sunday
    int systemDayNum;
    if (firstDayIndex == 0) {
      systemDayNum = 7; // Sunday
    } else {
      systemDayNum = firstDayIndex;
    }

    final days = {
      1: 'Monday',
      2: 'Tuesday',
      3: 'Wednesday',
      4: 'Thursday',
      5: 'Friday',
      6: 'Saturday',
      7: 'Sunday',
    };

    String systemDayLabel = days[systemDayNum] ?? 'Unknown';

    final options = {
      null: 'System Default ($systemDayLabel)',
      1: 'Monday',
      2: 'Tuesday',
      3: 'Wednesday',
      4: 'Thursday',
      5: 'Friday',
      6: 'Saturday',
      7: 'Sunday',
    };

    return ListTile(
      title: const Text('Start of the Week'),
      subtitle: Text(options[settings.firstDayOfWeek] ?? 'Unknown'),
      leading: const Icon(Icons.calendar_view_week),
      trailing: DropdownButton<int?>(
        value: settings.firstDayOfWeek,
        underline: const SizedBox(),
        alignment: Alignment.centerRight,
        onChanged: settings.setFirstDayOfWeek,
        items: options.entries
            .map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value),
                ))
            .toList(),
      ),
    );
  }
}