import 'package:sqflite_common/sqlite_api.dart';

const int MODEL_VERSION = 3;

class Budget {
  int? id;
  String title;
  double balance;
  BudgetSchedule schedule;

  Budget(
      {this.id,
      required this.title,
      this.balance = 0,
      required this.schedule});

  static Future<void> sqlCreate(Database db) =>
      db.execute('CREATE TABLE IF NOT EXISTS budget('
          'id INTEGER PRIMARY KEY, '
          'title TEXT, '
          'balance REAL, '
          'schedule INTEGER, '
          'FOREIGN KEY(schedule) REFERENCES budget_schedule(id))');

  static Future<int> insert(Database db, Budget budget) =>
      BudgetSchedule.insert(db, budget.schedule).then((schedule) => db
          .rawInsert(
              'INSERT INTO budget(title, balance, schedule) VALUES(?,?,?)',
              [budget.title, budget.balance, schedule]));

  static Future<int> delete(Database db, Budget budget) =>
      BudgetSchedule.delete(db, budget.schedule).then((schedule) =>
          db.rawDelete('DELETE FROM budget WHERE id = ?', [budget.id]));

  static Future<int> save(Database db, Budget budget) =>
      BudgetSchedule.save(db, budget.schedule).then((schedule) => db.rawUpdate(
          'UPDATE budget SET title = ?, balance = ? WHERE id = ?',
          [budget.title, budget.balance, budget.id]));

  factory Budget.fromJson(Map<String, dynamic> data) => Budget(
        id: data['id'],
        title: data['title'],
        balance: data['balance'],
        schedule: BudgetSchedule.fromJson(data),
      );

  Map<String, dynamic> toMap() =>
      {'id': id, 'title': title, 'balance': balance, 'schedule': schedule.id};
}

class Expense {
  int? id;
  int budget;
  double amount;
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
          'amount REAL, '
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
        amount: data['amount'],
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
  double budget;
  bool carryOver;
  Periodicity periodicity;
  int? periodParam;
  DateTime start;

  BudgetSchedule(
      {int? id,
      required this.budget,
      required this.carryOver,
      required this.periodicity,
      this.periodParam,
      required this.start});

  static Future<void> sqlCreate(Database db) =>
      db.execute('CREATE TABLE IF NOT EXISTS budget_schedule('
          'id INTEGER PRIMARY KEY, '
          'budget REAL, '
          'carryOver INTEGER, '
          'periodicity TEXT, '
          'periodParam INTEGER, '
          'start INTEGER)');

  static Future<int> insert(Database db, BudgetSchedule schedule) =>
      db.rawInsert(
          'INSERT INTO budget_schedule(budget, carryOver, periodicity, periodParam, start) VALUES(?,?,?,?,?)',
          [
            schedule.budget,
            schedule.carryOver ? 1 : 0,
            schedule.periodicity.toString(),
            schedule.periodParam,
            schedule.start.toUtc().millisecondsSinceEpoch
          ]);

  static Future<int> delete(Database db, BudgetSchedule schedule) =>
      db.rawDelete('DELETE FROM budget_schedule WHERE id = ?', [schedule.id]);

  static Future<int> save(Database db, BudgetSchedule schedule) => db.rawUpdate(
          'UPDATE budget_schedule SET budget = ?, carryOver = ?, periodicity = ?, periodParam = ?, start = ? WHERE id = ?',
          [
            schedule.budget,
            schedule.carryOver ? 1 : 0,
            schedule.periodicity.toString(),
            schedule.periodParam,
            schedule.start.toUtc().millisecondsSinceEpoch,
            schedule.id
          ]);

  factory BudgetSchedule.fromJson(Map<String, dynamic> data) => BudgetSchedule(
        id: data['schedule'],
        budget: data['budget'],
        carryOver: data['carryOver'] == 1 ? true : false,
        periodicity: Periodicity.values
            .firstWhere((element) => element.toString() == data['periodicity']),
        periodParam: data['periodParam'],
        start: DateTime.fromMillisecondsSinceEpoch(data['start'], isUtc: true),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'budget': budget,
        'carryOver': carryOver,
        'periodicity': periodicity.toString(),
        'periodParam': periodParam,
        'start': start.toUtc().millisecondsSinceEpoch,
      };
}

enum Periodicity { days, daily, weeks, weekly, months, monthly, years, yearly }
