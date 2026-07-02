import 'model.dart';

class BudgetCalculator {
  static (int balance, int carryOver, int totalExpired, Map<int, int> periodSpentMap, Map<int, int> periodExpirationMap) calculateBalances({
    required Budget budget,
    required List<Expense> expenses,
    required int currentPeriodIdx,
    String? locationName,
  }) {
    Map<int, int> periodSpentMap = {};
    for (var e in expenses) {
      int idx = budget.getPeriodIndex(e.dateTime, locationName: locationName);
      if (idx >= 0) {
        periodSpentMap[idx] = (periodSpentMap[idx] ?? 0) + e.amount;
      }
    }

    if (currentPeriodIdx < 0) return (0, 0, 0, periodSpentMap, {});

    Map<int, int> buckets = {};
    Map<int, int> periodExpirationMap = {};
    int totalExpired = 0;
    int b = budget.schedule.budget;
    int? limit = budget.schedule.carryOverLimit;

    for (int j = 0; j < currentPeriodIdx; j++) {
      // 1. Add allowance to current bucket
      buckets[j] = (buckets[j] ?? 0) + b;

      // 2. Pay off oldest debt with current allowance first
      if (buckets[j]! > 0) {
        List<int> debtIndices = buckets.keys.where((i) => buckets[i]! < 0).toList()..sort();
        for (int idx in debtIndices) {
          int debt = -buckets[idx]!;
          if (buckets[j]! >= debt) {
            buckets[j] = buckets[j]! - debt;
            buckets[idx] = 0;
          } else {
            buckets[idx] = buckets[idx]! + buckets[j]!;
            buckets[j] = 0;
            break;
          }
        }
      }

      // 3. Spend from oldest buckets first (FIFO)
      int toSpend = periodSpentMap[j] ?? 0;
      List<int> sortedIndices = buckets.keys.toList()..sort();
      for (int idx in sortedIndices) {
        if (toSpend <= 0) break;
        int available = buckets[idx]!;
        if (available > 0) {
          if (available >= toSpend) {
            buckets[idx] = available - toSpend;
            toSpend = 0;
          } else {
            buckets[idx] = 0;
            toSpend -= available;
          }
        }
      }
      // Remaining toSpend becomes debt in the current bucket
      if (toSpend > 0) {
        buckets[j] = buckets[j]! - toSpend;
      }

      // 4. Expiration: remove positive buckets that are too old
      if (limit != null) {
        int oldestAllowedIdx = j - limit + 1;
        int expiredInThisTransition = 0;
        for (int idx in buckets.keys.toList()) {
          if (idx <= oldestAllowedIdx && buckets[idx]! > 0) {
            expiredInThisTransition += buckets[idx]!;
            buckets.remove(idx);
          }
        }
        if (expiredInThisTransition > 0) {
          periodExpirationMap[j] = expiredInThisTransition;
          totalExpired += expiredInThisTransition;
        }
      }
    }

    int carryOver = buckets.values.fold(0, (sum, val) => sum + val);
    int balance = periodSpentMap[currentPeriodIdx] ?? 0;

    return (balance, carryOver, totalExpired, periodSpentMap, periodExpirationMap);
  }
}
