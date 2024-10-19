import 'dart:math';

import 'package:smart_budget/persistence/model.dart';

class Fixtures {
  static final _RNG = Random(123);
  static const _chars =
      'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';

  static Budget exampleBudget(
      {String? title,
      double? balance,
      double? budget,
      bool? carryOver,
      Periodicity? periodicity,
      DateTime? start}) {
    balance ??= _RNG.nextDouble() * 100;
    title ??= 'Budget ${getRandomString(5)}';
    return Budget(
        title: title,
        balance: balance,
        schedule: exampleSchedule(
            budget: budget,
            carryOver: carryOver,
            periodicity: periodicity,
            start: start));
  }

  static String getRandomString(int length) =>
      String.fromCharCodes(Iterable.generate(
          length, (_) => _chars.codeUnitAt(_RNG.nextInt(_chars.length))));

  static BudgetSchedule exampleSchedule(
      {double? budget,
      bool? carryOver,
      Periodicity? periodicity,
      DateTime? start}) {
    budget ??= _RNG.nextDouble() * 200;
    carryOver ??= true;
    periodicity ??= Periodicity.monthly;
    start ??= DateTime.now();
    return BudgetSchedule(
        budget: budget,
        carryOver: carryOver,
        periodicity: periodicity,
        start: start);
  }

  static Expense exampleExpense({required Budget budget, double? amount, DateTime? date}) {
    amount ??= _RNG.nextDouble() * 10;
    date ??= DateTime.now();
    return Expense(budget: budget.id!, amount: amount, dateTime: date);
  }
}
