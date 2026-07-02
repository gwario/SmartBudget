import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:timezone/timezone.dart' as tz;

import 'calculator.dart';
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
          await db.execute(
              'UPDATE budget SET balance = CAST(balance * 100 AS INTEGER)');
          await db.execute(
              'UPDATE budget_schedule SET budget = CAST(budget * 100 AS INTEGER)');
          await db.execute(
              'UPDATE expense SET amount = CAST(amount * 100 AS INTEGER)');
        }
        if (oldVersion < 5) {
          // Add currencyCode column safely
          var tableInfo =
              await db.rawQuery('PRAGMA table_info(budget_schedule)');
          bool columnExists =
              tableInfo.any((column) => column['name'] == 'currencyCode');
          if (!columnExists) {
            await db.execute(
                'ALTER TABLE budget_schedule ADD COLUMN currencyCode TEXT');
          }

          // Determine system currency
          String sysCurrency = NumberFormat().currencyName ?? 'USD';
          await db.execute(
              'UPDATE budget_schedule SET currencyCode = ?', [sysCurrency]);

          // Scale from cents to micros (factor 10,000) or from double to micros (factor 1,000,000)
          int factor = (oldVersion == 4) ? 10000 : 1000000;
          await db.execute('UPDATE budget SET balance = balance * ?', [factor]);
          await db.execute(
              'UPDATE budget_schedule SET budget = budget * ?', [factor]);
          await db.execute('UPDATE expense SET amount = amount * ?', [factor]);
        }
        if (oldVersion < 6) {
          // Add carryOver column to budget safely
          var tableInfo = await db.rawQuery('PRAGMA table_info(budget)');
          bool columnExists =
              tableInfo.any((column) => column['name'] == 'carryOver');
          if (!columnExists) {
            await db.execute(
                'ALTER TABLE budget ADD COLUMN carryOver INTEGER DEFAULT 0');
          }
        }
        if (oldVersion < 7) {
          // Add carryOverLimit column to budget_schedule safely
          var tableInfo =
              await db.rawQuery('PRAGMA table_info(budget_schedule)');
          bool columnExists =
              tableInfo.any((column) => column['name'] == 'carryOverLimit');
          if (!columnExists) {
            await db.execute(
                'ALTER TABLE budget_schedule ADD COLUMN carryOverLimit INTEGER');
          }
        }
        if (oldVersion < 8) {
          // Add totalExpired column to budget safely
          var tableInfo = await db.rawQuery('PRAGMA table_info(budget)');
          bool columnExists =
              tableInfo.any((column) => column['name'] == 'totalExpired');
          if (!columnExists) {
            await db.execute(
                'ALTER TABLE budget ADD COLUMN totalExpired INTEGER DEFAULT 0');
          }
        }
      },
      onOpen: (db) async {
        // Safety check for carryOverLimit
        var tableInfoSchedule =
            await db.rawQuery('PRAGMA table_info(budget_schedule)');
        if (!tableInfoSchedule
            .any((column) => column['name'] == 'carryOverLimit')) {
          await db.execute(
              'ALTER TABLE budget_schedule ADD COLUMN carryOverLimit INTEGER');
        }
        // Safety check for totalExpired
        var tableInfoBudget = await db.rawQuery('PRAGMA table_info(budget)');
        if (!tableInfoBudget
            .any((column) => column['name'] == 'totalExpired')) {
          await db.execute(
              'ALTER TABLE budget ADD COLUMN totalExpired INTEGER DEFAULT 0');
        }
      },
      version: MODEL_VERSION,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await BudgetSchedule.sqlCreate(db);
    await Budget.sqlCreate(db);
    return Expense.sqlCreate(db);
  }

  Future<List<Budget>> getBudgets() async {
    final db = await _databaseService.database;
    var data = await db.rawQuery(
        'SELECT budget_schedule.*, budget_schedule.carryOver as isCarryOver, budget.*, budget.carryOver as carryOverAmt '
        'FROM budget '
        'LEFT JOIN budget_schedule ON budget.schedule = budget_schedule.id;');
    List<Budget> budgets =
        List.generate(data.length, (index) => Budget.fromJson(data[index]));
    return budgets;
  }

  Future<int> updateBalances({String? locationName}) async {
    final db = await _databaseService.database;
    final location =
        locationName != null ? tz.getLocation(locationName) : tz.local;

    var data = await db.rawQuery(
        'SELECT budget_schedule.*, budget_schedule.carryOver as isCarryOver, budget.*, budget.carryOver as carryOverAmt '
        'FROM budget '
        'LEFT JOIN budget_schedule ON budget.schedule = budget_schedule.id;');
    List<Budget> budgets =
        List.generate(data.length, (index) => Budget.fromJson(data[index]));

    for (var budget in budgets) {
      final now = tz.TZDateTime.from(DateTime.now(), location);
      int currentPeriodIdx =
          budget.getPeriodIndex(now, locationName: locationName);

      if (currentPeriodIdx < 0) {
        budget.balance = 0;
        budget.carryOver = 0;
        budget.totalExpired = 0;
        await saveBudget(budget);
        continue;
      }

      var expensesData = await db.rawQuery(
          'SELECT amount, dateTime FROM expense WHERE budget = ? ORDER BY dateTime ASC',
          [budget.id]);
      List<Expense> expenses = expensesData.map((e) => Expense.fromJson({
        'id': 0, // Not needed for calculation
        'budget': budget.id,
        'amount': e['amount'],
        'dateTime': e['dateTime'],
      })).toList();

      final (balance, carryOver, totalExpired, _, _) = BudgetCalculator.calculateBalances(
        budget: budget,
        expenses: expenses,
        currentPeriodIdx: currentPeriodIdx,
        locationName: locationName,
      );

      budget.balance = balance;
      budget.carryOver = carryOver;
      budget.totalExpired = totalExpired;
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

  Future<void> deleteExpense(Expense expense) async {
    final db = await _databaseService.database;
    await Expense.delete(db, expense);
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
