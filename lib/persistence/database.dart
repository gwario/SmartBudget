import 'dart:developer';

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
    var data = await db.rawQuery('SELECT budget.*, budget_schedule.* '
        'FROM budget '
        'LEFT JOIN budget_schedule ON budget.schedule = budget_schedule.id;');
    List<Budget> budgets =
        List.generate(data.length, (index) => Budget.fromJson(data[index]));
    return budgets;
  }

  Future<int> updateBalances() async {
    final db = await _databaseService.database;
    var data = await db.rawQuery('SELECT budget.*, budget_schedule.* '
        'FROM budget '
        'LEFT JOIN budget_schedule ON budget.schedule = budget_schedule.id;');
    List<Budget> budgets =
    List.generate(data.length, (index) => Budget.fromJson(data[index]));

    for (var budget in budgets) {
      /* TODO
        * calculate periods
          * group by pattern from periodicity
        * get all expenses group by period, sum up, and if not carryOver, max(sum,budget).
        update budget with sum over all balances, or if not carryOver, only return balance of latest period
       */
      if (budget.schedule.carryOver) {
        String periodicityPattern;
        switch (budget.schedule.periodicity) {
          case Periodicity.monthly:
            periodicityPattern = '%Y-%m';
          case Periodicity.yearly:
            periodicityPattern = '%Y';
          default:
            throw ArgumentError('Unhandled periodicity "${budget.schedule.periodicity}"!');
        }
        var data = await db.rawQuery('SELECT '
            'sum(amount), '
            'strftime("?", timestamp) as period '
            'FROM expense '
            'GROUP BY strftime("?", timestamp) '
            'ORDER BY period '
            'WHERE budget = ?;', [periodicityPattern, budget.id]);
        log(data.toString());
      } else {
        DateTime now = DateTime.now();
        DateTime start;
        DateTime end;
        switch (budget.schedule.periodicity) {
          case Periodicity.monthly:
            start = DateTime(now.year, now.month);
            end = DateTime(now.month == 12 ? now.year + 1 : now.year, now.month == 12 ? 1 : now.month + 1).subtract(Duration(microseconds: 1));
          case Periodicity.yearly:
            start = DateTime(now.year);
            end = DateTime(now.year + 1).subtract(Duration(microseconds: 1));
          default:
            throw ArgumentError('Unhandled periodicity "${budget.schedule.periodicity}"!');
        }
        var data = await db.rawQuery('SELECT date, '
            'sum(amount) as balance, '
            'FROM expense '
            'WHERE budget = ? AND date BETWEEN "?" AND "?";', [budget.id, start.toIso8601String(), end.toIso8601String()]);
        log(data.toString());
      }
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
