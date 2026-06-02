import 'dart:math';

import 'package:smart_budget/persistence/model.dart';

class Fixtures {
  static final _rng = Random(123);
  static const _chars =
      'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';

  static Budget exampleBudget(
      {String? title,
      int? balance,
      int? budget,
      bool? carryOver,
      Periodicity? periodicity,
      DateTime? start,
      String? currencyCode}) {
    balance ??= (_rng.nextDouble() * 10000).toInt();
    title ??= 'Budget ${getRandomString(5)}';
    return Budget(
        title: title,
        balance: balance,
        schedule: exampleSchedule(
            budget: budget,
            carryOver: carryOver,
            periodicity: periodicity,
            start: start,
            currencyCode: currencyCode));
  }

  static String getRandomString(int length) =>
      String.fromCharCodes(Iterable.generate(
          length, (_) => _chars.codeUnitAt(_rng.nextInt(_chars.length))));

  static BudgetSchedule exampleSchedule(
      {int? budget,
      bool? carryOver,
      Periodicity? periodicity,
      DateTime? start,
      String? currencyCode}) {
    budget ??= (_rng.nextDouble() * 20000).toInt();
    carryOver ??= true;
    periodicity ??= Periodicity.monthly;
    start ??= DateTime.now();
    currencyCode ??= 'USD';
    return BudgetSchedule(
        budget: budget,
        carryOver: carryOver,
        periodicity: periodicity,
        start: start,
        currencyCode: currencyCode);
  }

  static Expense exampleExpense(
      {required Budget budget, int? amount, DateTime? date}) {
    amount ??= (_rng.nextDouble() * 1000).toInt();
    date ??= DateTime.now();
    return Expense(budget: budget.id!, amount: amount, dateTime: date);
  }
}
