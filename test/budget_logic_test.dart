import 'package:flutter_test/flutter_test.dart';
import 'package:smart_budget/persistence/calculator.dart';
import 'package:smart_budget/persistence/model.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  tz.initializeTimeZones();

  group('Budget Logic Tests', () {
    test('Monthly budget starting Nov 1st 12:00 (UTC-5) correctly starts on Nov 1st', () {
      // Nov 1st 12:00 in New York (EDT, UTC-4) is Nov 1st 16:00 UTC
      final start = DateTime.utc(2024, 11, 1, 16, 0);
      
      final budget = Budget(
        title: 'NY Test',
        schedule: BudgetSchedule(
          budget: 1000,
          carryOver: true,
          periodicity: Periodicity.monthly,
          start: start,
          currencyCode: 'USD',
        ),
      );

      // Simulating "current time" as Nov 1st 17:00 UTC (which is 13:00 local in NY)
      final testDate = DateTime.utc(2024, 11, 1, 17, 0); 
      
      final index = budget.getPeriodIndex(testDate, locationName: 'America/New_York');
      expect(index, 0, reason: 'Should be in the first period (index 0)');
    });

    test('Monthly budget starting Nov 1st 12:00 (UTC+1) correctly starts on Nov 1st', () {
      // Nov 1st 12:00 in Berlin (CET, UTC+1) is Nov 1st 11:00 UTC
      final start = DateTime.utc(2024, 11, 1, 11, 0);
      
      final budget = Budget(
        title: 'Berlin Test',
        schedule: BudgetSchedule(
          budget: 1000,
          carryOver: true,
          periodicity: Periodicity.monthly,
          start: start,
          currencyCode: 'EUR',
        ),
      );

      final testDate = DateTime.utc(2024, 11, 1, 15, 0); // Mid-day Berlin
      
      final index = budget.getPeriodIndex(testDate, locationName: 'Europe/Berlin');
      expect(index, 0, reason: 'Should be in the first period (index 0)');
    });
    
    test('Daily budget normalization near midnight local time', () {
      // Start day: Oct 10 at Noon (safe storage strategy)
      final start = DateTime(2024, 10, 10, 12, 0);
      final budget = Budget(
        title: 'Daily',
        schedule: BudgetSchedule(
          budget: 100,
          carryOver: false,
          periodicity: Periodicity.daily,
          start: start,
          currencyCode: 'USD'
        )
      );

      // Check Oct 10 00:05 AM (before the 12:00 PM start time, but same calendar day)
      final earlyMorning = DateTime(2024, 10, 10, 0, 5);
      expect(budget.getPeriodIndex(earlyMorning), 0, 
          reason: 'Daily budget should start at 00:00 of the start day due to normalization');

      // Check Oct 9 23:55 PM (day before)
      final dayBefore = DateTime(2024, 10, 9, 23, 55);
      expect(budget.getPeriodIndex(dayBefore), -1,
          reason: 'Should not have started yet (previous calendar day)');
          
      // Check next day
      final nextDay = DateTime(2024, 10, 11, 0, 1);
      expect(budget.getPeriodIndex(nextDay), 1, 
          reason: 'Should be the second period (index 1)');
    });

    test('High-frequency periodicity (minutes) does NOT normalize to start of day', () {
      final start = DateTime(2024, 10, 10, 12, 0);
      final budget = Budget(
        title: 'HighFreq',
        schedule: BudgetSchedule(
          budget: 100,
          carryOver: false,
          periodicity: Periodicity.minutes,
          start: start,
          currencyCode: 'USD'
        )
      );

      // 5 minutes before start
      final before = start.subtract(const Duration(minutes: 5));
      expect(budget.getPeriodIndex(before), -1);

      // Exactly at start
      expect(budget.getPeriodIndex(start), 0);

      // 5 minutes after start
      final after = start.add(const Duration(minutes: 5));
      expect(budget.getPeriodIndex(after), 5);
    });
    
    test('Monthly rollover with periodParam > 1', () {
      final start = DateTime(2024, 1, 1, 12, 0);
      final budget = Budget(
        title: 'Bi-Monthly',
        schedule: BudgetSchedule(
          budget: 1000,
          carryOver: true,
          periodicity: Periodicity.months,
          periodParam: 2, // Every 2 months
          start: start,
          currencyCode: 'USD'
        )
      );

      // Jan is index 0
      expect(budget.getPeriodIndex(DateTime(2024, 1, 15)), 0);
      // Feb is still index 0
      expect(budget.getPeriodIndex(DateTime(2024, 2, 15)), 0);
      // March is index 1
      expect(budget.getPeriodIndex(DateTime(2024, 3, 15)), 1);
    });

    test('Rollover expiration with 3 periods and limit 2', () {
      final start = DateTime(2024, 1, 1, 12, 0);
      final budget = Budget(
        title: 'Limit Test',
        schedule: BudgetSchedule(
          budget: 1000,
          carryOver: true,
          carryOverLimit: 2,
          periodicity: Periodicity.monthly,
          start: start,
          currencyCode: 'USD',
        ),
      );

      // No expenses
      final expenses = <Expense>[];

      // Current period: March (index 2)
      final (balance, carryOver, totalExpired, _, _) = BudgetCalculator.calculateBalances(
        budget: budget,
        expenses: expenses,
        currentPeriodIdx: 2,
      );

      // Period 0 (Jan): $1000 added.
      // End of Jan: rolls to Feb.
      // Period 1 (Feb): $1000 added. Total $2000.
      // End of Feb: Jan ($1000) expires because limit is 2.
      // Period 2 (March): Rollover should be $1000 (from Feb only).
      expect(carryOver, 1000, reason: 'Jan money should have expired by March');
      expect(totalExpired, 1000, reason: 'Total expired should track the Jan surplus');
      expect(balance, 0, reason: 'March spent is 0');
    });

    test('Rollover with debt - debt should NOT expire', () {
      final start = DateTime(2024, 1, 1, 12, 0);
      final budget = Budget(
        title: 'Debt Test',
        schedule: BudgetSchedule(
          budget: 1000,
          carryOver: true,
          carryOverLimit: 2,
          periodicity: Periodicity.monthly,
          start: start,
          currencyCode: 'USD',
        ),
      );

      // Spent $2500 in Jan (idx 0). Allowance is $1000. Debt is $1500.
      final expenses = [
        Expense(budget: 1, amount: 2500, dateTime: DateTime(2024, 1, 5)),
      ];

      // Current period: March (index 2)
      final (balance, carryOver, totalExpired, _, _) = BudgetCalculator.calculateBalances(
        budget: budget,
        expenses: expenses,
        currentPeriodIdx: 2,
      );

      // Jan (0): Avail 1000. Spent 2500. Remaining -1500.
      // End of Jan: Debt -1500 rolls to Feb.
      // Feb (1): Avail 1000 + (-1500) = -500. Spent 0. Remaining -500.
      // End of Feb: Debt -500 rolls to March. (Debt never expires).
      // March (2): Avail 1000 + (-500) = 500.
      expect(carryOver, -500, reason: 'Debt should persist and be paid down by Feb allowance');
      expect(totalExpired, 0, reason: 'Debt does not expire');
    });
  });
}
