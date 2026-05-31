import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'model.dart';

class DatabaseService {
  static final DatabaseService _databaseService = DatabaseService._internal();

  factory DatabaseService() => _databaseService;

  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDatabase();
    return _database!;
  }

  Future<Database> initDatabase() async {
    return await openDatabase(
      join(await getDatabasesPath(), 'budget_database.db'),
      onCreate: (db, version) async => DatabaseService._onCreate(db, version),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 4) {
          // Migration from double to int (cents)
          await db.execute('UPDATE budget SET balance = CAST(balance * 100 AS INTEGER)');
          await db.execute('UPDATE budget_schedule SET budget = CAST(budget * 100 AS INTEGER)');
          await db.execute('UPDATE expense SET amount = CAST(amount * 100 AS INTEGER)');
        }
        if (oldVersion < 5) {
          // Add currencyCode column safely
          var tableInfo = await db.rawQuery('PRAGMA table_info(budget_schedule)');
          bool columnExists = tableInfo.any((column) => column['name'] == 'currencyCode');
          if (!columnExists) {
            await db.execute('ALTER TABLE budget_schedule ADD COLUMN currencyCode TEXT');
          }
          
          // Determine system currency
          String sysCurrency = NumberFormat().currencyName ?? 'USD';
          await db.execute('UPDATE budget_schedule SET currencyCode = ?', [sysCurrency]);

          // Scale from cents to micros (factor 10,000) or from double to micros (factor 1,000,000)
          int factor = (oldVersion == 4) ? 10000 : 1000000;
          await db.execute('UPDATE budget SET balance = balance * ?', [factor]);
          await db.execute('UPDATE budget_schedule SET budget = budget * ?', [factor]);
          await db.execute('UPDATE expense SET amount = amount * ?', [factor]);
        }
        if (oldVersion < 6) {
          // Add carryOver column to budget safely
          var tableInfo = await db.rawQuery('PRAGMA table_info(budget)');
          bool columnExists = tableInfo.any((column) => column['name'] == 'carryOver');
          if (!columnExists) {
            await db.execute('ALTER TABLE budget ADD COLUMN carryOver INTEGER DEFAULT 0');
          }
        }
      },
      version: modelVersion,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await BudgetSchedule.sqlCreate(db);
    await Budget.sqlCreate(db);
    return Expense.sqlCreate(db);
  }

  Future<List<Budget>> getBudgets() async {
    final db = await _databaseService.database;
    var data = await db.rawQuery('SELECT budget_schedule.*, budget_schedule.carryOver as isCarryOver, budget.*, budget.carryOver as carryOverAmt '
        'FROM budget '
        'LEFT JOIN budget_schedule ON budget.schedule = budget_schedule.id;');
    List<Budget> budgets =
        List.generate(data.length, (index) => Budget.fromJson(data[index]));
    return budgets;
  }

  Future<int> updateBalances() async {
    final db = await _databaseService.database;
    var data = await db.rawQuery('SELECT budget_schedule.*, budget_schedule.carryOver as isCarryOver, budget.*, budget.carryOver as carryOverAmt '
        'FROM budget '
        'LEFT JOIN budget_schedule ON budget.schedule = budget_schedule.id;');
    List<Budget> budgets =
    List.generate(data.length, (index) => Budget.fromJson(data[index]));

    for (var budget in budgets) {
      int currentSpent;
      int carryOver = 0;

      DateTime now = DateTime.now().toUtc();
      DateTime currentPeriodStart;

      switch (budget.schedule.periodicity) {
        case Periodicity.seconds:
          currentPeriodStart = budget.schedule.start.add(Duration(seconds: now.difference(budget.schedule.start).inSeconds));
        case Periodicity.minutes:
          currentPeriodStart = budget.schedule.start.add(Duration(minutes: now.difference(budget.schedule.start).inMinutes));
        case Periodicity.hours:
          currentPeriodStart = budget.schedule.start.add(Duration(hours: now.difference(budget.schedule.start).inHours));
        case Periodicity.daily:
        case Periodicity.days:
          currentPeriodStart = DateTime.utc(now.year, now.month, now.day);
        case Periodicity.weekly:
        case Periodicity.weeks:
          int daysFromMonday = now.weekday - 1;
          currentPeriodStart = DateTime.utc(now.year, now.month, now.day - daysFromMonday);
        case Periodicity.monthly:
        case Periodicity.months:
          currentPeriodStart = DateTime.utc(now.year, now.month, 1);
        case Periodicity.yearly:
        case Periodicity.years:
          currentPeriodStart = DateTime.utc(now.year, 1, 1);
      }

      if (currentPeriodStart.isBefore(budget.schedule.start)) {
        currentPeriodStart = budget.schedule.start;
      }

      // 1. Current Period Spent
      var dataCurrent = await db.rawQuery(
          'SELECT sum(amount) as spent FROM expense WHERE budget = ? AND dateTime >= ?',
          [budget.id, currentPeriodStart.millisecondsSinceEpoch]);
      currentSpent = (dataCurrent.first['spent'] as num?)?.toInt() ?? 0;

      // 2. Carry Over (if enabled)
      if (budget.schedule.carryOver) {
        var dataPast = await db.rawQuery(
            'SELECT sum(amount) as spent FROM expense WHERE budget = ? AND dateTime < ? AND dateTime >= ?',
            [budget.id, currentPeriodStart.millisecondsSinceEpoch, budget.schedule.start.millisecondsSinceEpoch]);
        int pastSpent = (dataPast.first['spent'] as num?)?.toInt() ?? 0;
        int pastPeriods = budget.periodsElapsed - 1;
        carryOver = (pastPeriods * budget.schedule.budget) - pastSpent;
      }

      budget.balance = currentSpent;
      budget.carryOver = carryOver;
      await saveBudget(budget);
    }

    return budgets.length;
  }

  Future<void> insertBudget(Budget budget) async {
    final db = await _databaseService.database;
    await Budget.insert(db, budget);
  }

  Future<void> deleteBudget(Budget budget) async {
    final db = await _databaseService.database;
    await Budget.delete(db, budget);
  }

  Future<void> saveBudget(Budget budget) async {
    final db = await _databaseService.database;
    await Budget.save(db, budget);
  }

  Future<void> insertExpense(Expense expense) async {
    final db = await _databaseService.database;
    await Expense.insert(db, expense);
  }

  Future<List<Expense>> getExpenses(int budgetId) async {
    final db = await _databaseService.database;
    var data = await db.rawQuery(
        'SELECT * '
        'FROM expense '
        'WHERE budget = ?;',
        [budgetId]);
    List<Expense> expenses =
        List.generate(data.length, (index) => Expense.fromJson(data[index]));
    return expenses;
  }

// Future<void> editMovie(MovieModel movie) async {
//   final db = await _databaseService.database;
//   var data = await db.rawUpdate(
//       'UPDATE Movies SET title=?,language=?,year=? WHERE ID=?',
//       [movie.title, movie.language, movie.year, movie.id]);
//   log('updated $data');
// }
// Future<void> deleteMovie(String id) async {
//   final db = await _databaseService.database;
//   var data = await db.rawDelete('DELETE from Movies WHERE id=?', [id]);
//   log('deleted $data');
// }
}
