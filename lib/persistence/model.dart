import 'package:intl/intl.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:timezone/timezone.dart' as tz;

const int MODEL_VERSION = 8;

class Budget {
  int? id;
  String title;
  int balance; // Spent in current period (micros)
  int carryOver; // Accumulated from past periods (micros)
  int totalExpired; // Total amount expired over time (micros)
  BudgetSchedule schedule;

  Budget(
      {this.id,
      required this.title,
      this.balance = 0,
      this.carryOver = 0,
      this.totalExpired = 0,
      required this.schedule});

  static Future<void> sqlCreate(Database db) =>
      db.execute('CREATE TABLE IF NOT EXISTS budget('
          'id INTEGER PRIMARY KEY, '
          'title TEXT, '
          'balance INTEGER, '
          'carryOver INTEGER DEFAULT 0, '
          'totalExpired INTEGER DEFAULT 0, '
          'schedule INTEGER, '
          'FOREIGN KEY(schedule) REFERENCES budget_schedule(id))');

  static Future<int> insert(Database db, Budget budget) async {
    final scheduleId = await BudgetSchedule.insert(db, budget.schedule);
    budget.schedule.id = scheduleId;
    final budgetId = await db.rawInsert(
        'INSERT INTO budget(title, balance, carryOver, totalExpired, schedule) VALUES(?,?,?,?,?)',
        [
          budget.title,
          budget.balance,
          budget.carryOver,
          budget.totalExpired,
          scheduleId
        ]);
    budget.id = budgetId;
    return budgetId;
  }

  static Future<int> delete(Database db, Budget budget) async {
    await db.rawDelete('DELETE FROM expense WHERE budget = ?', [budget.id]);
    return BudgetSchedule.delete(db, budget.schedule).then((schedule) =>
        db.rawDelete('DELETE FROM budget WHERE id = ?', [budget.id]));
  }

  static Future<int> save(Database db, Budget budget) =>
      BudgetSchedule.save(db, budget.schedule).then((schedule) => db.rawUpdate(
          'UPDATE budget SET title = ?, balance = ?, carryOver = ?, totalExpired = ? WHERE id = ?',
          [
            budget.title,
            budget.balance,
            budget.carryOver,
            budget.totalExpired,
            budget.id
          ]));

  factory Budget.fromJson(Map<String, dynamic> data) => Budget(
        id: data['budget_id'] ?? data['id'],
        title: data['title'],
        balance: (data['balance'] as num).toInt(),
        carryOver:
            (data['carryOverAmt'] ?? data['carryOver'] as num?)?.toInt() ?? 0,
        totalExpired: (data['totalExpired'] as num?)?.toInt() ?? 0,
        schedule: BudgetSchedule.fromJson(data),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'balance': balance,
        'carryOver': carryOver,
        'totalExpired': totalExpired,
        'schedule': schedule.id
      };

  int get totalBudget => schedule.budget + carryOver;

  int getPeriodsElapsed({String? locationName}) {
    final location =
        locationName != null ? tz.getLocation(locationName) : tz.local;
    final now = tz.TZDateTime.from(DateTime.now(), location);
    final start = tz.TZDateTime.from(schedule.start, location);

    if (now.isBefore(start)) return 0;

    int n = schedule.periodParam ?? 1;
    int units = 0;
    switch (schedule.periodicity) {
      case Periodicity.seconds:
        units = now.difference(start).inSeconds;
        break;
      case Periodicity.minutes:
        units = now.difference(start).inMinutes;
        break;
      case Periodicity.hours:
        units = now.difference(start).inHours;
        break;
      case Periodicity.daily:
      case Periodicity.days:
        units = now.difference(start).inDays;
        break;
      case Periodicity.weekly:
      case Periodicity.weeks:
        units = (now.difference(start).inDays / 7).floor();
        break;
      case Periodicity.monthly:
      case Periodicity.months:
        units = (now.year - start.year) * 12 + (now.month - start.month);
        break;
      case Periodicity.yearly:
      case Periodicity.years:
        units = (now.year - start.year);
        break;
    }
    return (units / n).floor() + 1;
  }

  int get periodsElapsed => getPeriodsElapsed();

  double get utilization => totalBudget == 0 ? 0 : balance / totalBudget;

  int getPeriodIndex(DateTime dt, {String? locationName}) {
    final location =
        locationName != null ? tz.getLocation(locationName) : tz.local;
    final start = tz.TZDateTime.from(schedule.start, location);
    final d = tz.TZDateTime.from(dt, location);

    if (d.isBefore(start)) return -1;

    int n = schedule.periodParam ?? 1;
    int units = 0;
    switch (schedule.periodicity) {
      case Periodicity.seconds:
        units = d.difference(start).inSeconds;
        break;
      case Periodicity.minutes:
        units = d.difference(start).inMinutes;
        break;
      case Periodicity.hours:
        units = d.difference(start).inHours;
        break;
      case Periodicity.daily:
      case Periodicity.days:
        units = d.difference(start).inDays;
        break;
      case Periodicity.weekly:
      case Periodicity.weeks:
        units = (d.difference(start).inDays / 7).floor();
        break;
      case Periodicity.monthly:
      case Periodicity.months:
        units = (d.year - start.year) * 12 + (d.month - start.month);
        break;
      case Periodicity.yearly:
      case Periodicity.years:
        units = (d.year - start.year);
        break;
    }
    return (units / n).floor();
  }

  DateTime getPeriodStart(int index, {String? locationName}) {
    final location =
        locationName != null ? tz.getLocation(locationName) : tz.local;
    final start = tz.TZDateTime.from(schedule.start, location);
    int n = schedule.periodParam ?? 1;
    int totalUnits = index * n;

    switch (schedule.periodicity) {
      case Periodicity.seconds:
        return start.add(Duration(seconds: totalUnits));
      case Periodicity.minutes:
        return start.add(Duration(minutes: totalUnits));
      case Periodicity.hours:
        return start.add(Duration(hours: totalUnits));
      case Periodicity.daily:
      case Periodicity.days:
        return start.add(Duration(days: totalUnits));
      case Periodicity.weekly:
      case Periodicity.weeks:
        return start.add(Duration(days: totalUnits * 7));
      case Periodicity.monthly:
      case Periodicity.months:
        return tz.TZDateTime(location, start.year, start.month + totalUnits,
            start.day, start.hour, start.minute, start.second);
      case Periodicity.yearly:
      case Periodicity.years:
        return tz.TZDateTime(location, start.year + totalUnits, start.month,
            start.day, start.hour, start.minute, start.second);
    }
  }

  String formatCurrency(num microAmount, {int decimalDigits = 0}) {
    final format = NumberFormat.simpleCurrency(
        name: schedule.currencyCode, decimalDigits: decimalDigits);
    return format.format(microAmount / 1000000.0);
  }
}

class Expense {
  int? id;
  int budget;
  int amount; // Stored in micros
  DateTime dateTime;

  Expense(
      {this.id,
      required this.budget,
      required this.amount,
      required this.dateTime});

  static Future<void> sqlCreate(Database db) =>
      db.execute('CREATE TABLE IF NOT EXISTS expense('
          'id INTEGER PRIMARY KEY, '
          'budget INTEGER, '
          'amount INTEGER, '
          'dateTime INTEGER, '
          'FOREIGN KEY(budget) REFERENCES budget(id))');

  static Future<int> insert(Database db, Expense expense) => db.rawInsert(
          'INSERT INTO expense(budget, amount, dateTime) VALUES(?,?,?)', [
        expense.budget,
        expense.amount,
        expense.dateTime.toUtc().millisecondsSinceEpoch
      ]);

  static Future<int> delete(Database db, Expense expense) =>
      db.rawDelete('DELETE FROM expense WHERE id = ?', [expense.id]);

  factory Expense.fromJson(Map<String, dynamic> data) => Expense(
        id: data['id'],
        budget: data['budget'],
        amount: (data['amount'] as num).toInt(),
        dateTime:
            DateTime.fromMillisecondsSinceEpoch(data['dateTime'], isUtc: true),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'budget': budget,
        'amount': amount,
        'dateTime': dateTime.toUtc().millisecondsSinceEpoch
      };
}

class BudgetSchedule {
  int? id;
  int budget; // Stored in micros
  bool carryOver;
  int? carryOverLimit;
  Periodicity periodicity;
  int? periodParam;
  DateTime start;
  String currencyCode;

  BudgetSchedule(
      {int? id,
      required this.budget,
      required this.carryOver,
      this.carryOverLimit,
      required this.periodicity,
      this.periodParam,
      required this.start,
      required this.currencyCode});

  static Future<void> sqlCreate(Database db) =>
      db.execute('CREATE TABLE IF NOT EXISTS budget_schedule('
          'id INTEGER PRIMARY KEY, '
          'budget INTEGER, '
          'carryOver INTEGER, '
          'carryOverLimit INTEGER, '
          'periodicity TEXT, '
          'periodParam INTEGER, '
          'start INTEGER, '
          'currencyCode TEXT)');

  static Future<int> insert(Database db, BudgetSchedule schedule) =>
      db.rawInsert(
          'INSERT INTO budget_schedule(budget, carryOver, carryOverLimit, periodicity, periodParam, start, currencyCode) VALUES(?,?,?,?,?,?,?)',
          [
            schedule.budget,
            schedule.carryOver ? 1 : 0,
            schedule.carryOverLimit,
            schedule.periodicity.toString(),
            schedule.periodParam,
            schedule.start.toUtc().millisecondsSinceEpoch,
            schedule.currencyCode
          ]);

  static Future<int> delete(Database db, BudgetSchedule schedule) =>
      db.rawDelete('DELETE FROM budget_schedule WHERE id = ?', [schedule.id]);

  static Future<int> save(Database db, BudgetSchedule schedule) => db.rawUpdate(
          'UPDATE budget_schedule SET budget = ?, carryOver = ?, carryOverLimit = ?, periodicity = ?, periodParam = ?, start = ?, currencyCode = ? WHERE id = ?',
          [
            schedule.budget,
            schedule.carryOver ? 1 : 0,
            schedule.carryOverLimit,
            schedule.periodicity.toString(),
            schedule.periodParam,
            schedule.start.toUtc().millisecondsSinceEpoch,
            schedule.currencyCode,
            schedule.id
          ]);

  factory BudgetSchedule.fromJson(Map<String, dynamic> data) => BudgetSchedule(
        id: data['schedule'],
        budget: (data['budget'] as num).toInt(),
        carryOver:
            (data['isCarryOver'] ?? data['carryOver']) == 1 ? true : false,
        carryOverLimit: data['carryOverLimit'],
        periodicity: Periodicity.values
            .firstWhere((element) => element.toString() == data['periodicity']),
        periodParam: data['periodParam'],
        start: DateTime.fromMillisecondsSinceEpoch(data['start'], isUtc: true),
        currencyCode: data['currencyCode'] ?? 'USD',
      );

  String get periodLabel {
    int n = periodParam ?? 1;
    switch (periodicity) {
      case Periodicity.seconds:
        return n == 1 ? 'per second' : 'per $n seconds';
      case Periodicity.minutes:
        return n == 1 ? 'per minute' : 'per $n minutes';
      case Periodicity.hours:
        return n == 1 ? 'per hour' : 'per $n hours';
      case Periodicity.daily:
      case Periodicity.days:
        return n == 1 ? 'per day' : 'per $n days';
      case Periodicity.weekly:
      case Periodicity.weeks:
        return n == 1 ? 'per week' : 'per $n weeks';
      case Periodicity.monthly:
      case Periodicity.months:
        return n == 1 ? 'per month' : 'per $n months';
      case Periodicity.yearly:
      case Periodicity.years:
        return n == 1 ? 'per year' : 'per $n years';
    }
  }

  String get periodLabelShort {
    int n = periodParam ?? 1;
    String unit;
    switch (periodicity) {
      case Periodicity.seconds:
        unit = 's';
        break;
      case Periodicity.minutes:
        unit = 'm';
        break;
      case Periodicity.hours:
        unit = 'h';
        break;
      case Periodicity.daily:
      case Periodicity.days:
        unit = 'd';
        break;
      case Periodicity.weekly:
      case Periodicity.weeks:
        unit = 'w';
        break;
      case Periodicity.monthly:
      case Periodicity.months:
        unit = 'mo';
        break;
      case Periodicity.yearly:
      case Periodicity.years:
        unit = 'y';
        break;
    }
    return 'per $n$unit';
  }

  String getDurationLabel(int periodCount) {
    int totalUnits = periodCount * (periodParam ?? 1);
    String unit;
    switch (periodicity) {
      case Periodicity.minutes:
        unit = totalUnits == 1 ? 'minute' : 'minutes';
        break;
      case Periodicity.hours:
        unit = totalUnits == 1 ? 'hour' : 'hours';
        break;
      case Periodicity.daily:
      case Periodicity.days:
        unit = totalUnits == 1 ? 'day' : 'days';
        break;
      case Periodicity.weekly:
      case Periodicity.weeks:
        unit = totalUnits == 1 ? 'week' : 'weeks';
        break;
      case Periodicity.monthly:
      case Periodicity.months:
        unit = totalUnits == 1 ? 'month' : 'months';
        break;
      case Periodicity.yearly:
      case Periodicity.years:
        unit = totalUnits == 1 ? 'year' : 'years';
        break;
      default:
        unit = totalUnits == 1 ? 'period' : 'periods';
    }
    return '$totalUnits $unit ($periodCount periods)';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'budget': budget,
        'carryOver': carryOver,
        'carryOverLimit': carryOverLimit,
        'periodicity': periodicity.toString(),
        'periodParam': periodParam,
        'start': start.toUtc().millisecondsSinceEpoch,
        'currencyCode': currencyCode,
      };
}

enum Periodicity {
  seconds,
  minutes,
  hours,
  days,
  daily,
  weeks,
  weekly,
  months,
  monthly,
  years,
  yearly
}
