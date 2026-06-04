import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'package:flutter_localizations/flutter_localizations.dart';

import 'budget_list.dart';
import 'settings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  tz.initializeTimeZones();

  Intl.defaultLocale = Platform.localeName;

  runApp(
    ChangeNotifierProvider(
      create: (_) => SettingsProvider(),
      child: const BudgetScheduleApp(),
    ),
  );
}

class BudgetScheduleApp extends StatelessWidget {
  const BudgetScheduleApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final locale = settings.locale != null ? Locale(settings.locale!) : null;

    if (settings.locale != null) {
      Intl.defaultLocale = settings.locale;
    } else {
      Intl.defaultLocale = Platform.localeName;
    }

    return MaterialApp(
      title: 'Budget Schedule',
      locale: locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('en', 'GB'),
        Locale('en', 'AT'),
        Locale('de', 'AT'),
        Locale('de', 'DE'),
        Locale('es', 'ES'),
        Locale('fr', 'FR'),
        Locale('it', 'IT'),
        Locale('pt', 'BR'),
        Locale('ru', 'RU'),
        Locale('zh', 'CN'),
        Locale('ja', 'JP'),
        Locale('ko', 'KR'),
      ],
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const OverviewPage(title: 'My Budgets'),
    );
  }
}
