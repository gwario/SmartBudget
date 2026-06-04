import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_budget/persistence/database.dart';
import 'package:smart_budget/settings.dart';

import 'persistence/model.dart';

class BudgetDetail extends StatefulWidget {
  const BudgetDetail({super.key});

  @override
  State<StatefulWidget> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetDetail> {
  final dbService = DatabaseService();
  late CurrencyTextInputFormatter _expenseCurrencyFormatter;

  @override
  void initState() {
    super.initState();
    _expenseCurrencyFormatter = CurrencyTextInputFormatter.currency(
        locale: Intl.getCurrentLocale(),
        enableNegative: false,
        decimalDigits: 2,
        minValue: 0);
  }

  @override
  Widget build(BuildContext context) {
    final budgetArg = ModalRoute.of(context)!.settings.arguments as Budget;
    final settings = Provider.of<SettingsProvider>(context);

    return FutureBuilder<List<Budget>>(
        future: dbService.getBudgets(),
        builder: (context, budgetsSnapshot) {
          if (!budgetsSnapshot.hasData) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          final budgetIndex =
              budgetsSnapshot.data!.indexWhere((b) => b.id == budgetArg.id);
          if (budgetIndex == -1) {
            return const Scaffold(body: Center(child: Text('Budget deleted')));
          }
          final budget = budgetsSnapshot.data![budgetIndex];
          return Scaffold(
              appBar: AppBar(
                  leading: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.black)),
                  backgroundColor: Theme.of(context).colorScheme.inversePrimary,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () async {
                        final settings = context.read<SettingsProvider>();
                        await dbService.updateBalances(
                            locationName: settings.timezone);
                        setState(() {});
                      },
                    )
                  ],
                  title: SafeArea(
                      child: Text(
                    budget.title,
                    overflow: TextOverflow.ellipsis,
                  ))),
              body: Padding(
                  padding: const EdgeInsets.all(10),
                  child: SafeArea(
                    child: FutureBuilder<List<Expense>>(
                        future: dbService.getExpenses(budget.id!),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return const Center(child: Text('Error.'));
                          }
                          final expenses = snapshot.data ?? [];
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSummaryHeader(budget, expenses, settings),
                              const SizedBox(height: 15),
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: expenses.isEmpty
                                        ? [
                                            const Center(
                                                child: Text('No expenses yet.'))
                                          ]
                                        : _buildGroupedExpenses(
                                            budget, expenses, settings),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                  )),
              floatingActionButton: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FloatingActionButton(
                      onPressed: () => _addExpense(budget),
                      tooltip: 'Add',
                      heroTag: null,
                      child: const Icon(Icons.monetization_on),
                    ),
                  ),
                  FloatingActionButton(
                    onPressed: () => _deleteBudget(budget),
                    tooltip: 'Delete',
                    heroTag: null,
                    child: const Icon(Icons.delete_forever),
                  )
                ],
              ));
        });
  }

  Widget _buildSummaryHeader(
      Budget budget, List<Expense> expenses, SettingsProvider settings) {
    int currentPeriodIdx =
        budget.getPeriodsElapsed(locationName: settings.timezone) - 1;

    int carryFromPrev = 0;
    int carryFromOlder = 0;
    int expiredInThisPeriod = 0;

    if (budget.schedule.carryOver && currentPeriodIdx >= 0) {
      Map<int, int> periodSpentMap = {};
      for (var e in expenses) {
        int idx =
            budget.getPeriodIndex(e.dateTime, locationName: settings.timezone);
        if (idx >= 0) {
          periodSpentMap[idx] = (periodSpentMap[idx] ?? 0) + e.amount;
        }
      }

      int currentCarryIn = 0;
      int B = budget.schedule.budget;
      int? limit = budget.schedule.carryOverLimit;

      for (int j = 0; j <= currentPeriodIdx; j++) {
        int avail = B + currentCarryIn;
        int spent = periodSpentMap[j] ?? 0;
        int remaining = avail - spent;

        if (j == currentPeriodIdx) {
          if (j > 0) {
            carryFromPrev = B - (periodSpentMap[j - 1] ?? 0);
            carryFromOlder = currentCarryIn - carryFromPrev;
          }
        }

        // Calculate carryIn for j+1
        int nextCarryIn = 0;
        int k = j + 1;
        int n = limit ?? k;
        if (n > k) n = k;
        int firstIdx = k - n;

        int totalAllowanceInWindow = n * B;
        int totalSpentInWindow = 0;
        for (int i = firstIdx; i < k; i++) {
          totalSpentInWindow += periodSpentMap[i] ?? 0;
        }
        int windowCarryIn = totalAllowanceInWindow - totalSpentInWindow;

        if (remaining < 0) {
          nextCarryIn = remaining;
        } else {
          nextCarryIn = remaining < windowCarryIn
              ? remaining
              : (windowCarryIn > 0 ? windowCarryIn : 0);
        }

        if (j == currentPeriodIdx) {
          expiredInThisPeriod = remaining - nextCarryIn;
        }
        currentCarryIn = nextCarryIn;
      }
    }

    int totalSpent = expenses.fold(0, (sum, e) => sum + e.amount);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Base Budget', style: TextStyle(fontSize: 16)),
            Text(
                '${budget.formatCurrency(budget.schedule.budget)} ${budget.schedule.periodLabel}',
                style: const TextStyle(fontSize: 16))
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total Spent', style: TextStyle(fontSize: 16)),
                const Text('Since start',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            Text(budget.formatCurrency(totalSpent),
                style: const TextStyle(fontSize: 16))
          ],
        ),
        if (budget.schedule.carryOver) ...[
          if (budget.totalExpired > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Savings', style: TextStyle(fontSize: 16)),
                    const Text('Expired positive carry over',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                Text(budget.formatCurrency(budget.totalExpired),
                    style: const TextStyle(fontSize: 18, color: Colors.blue))
              ],
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Carry Over', style: TextStyle(fontSize: 16)),
                  if (budget.schedule.carryOverLimit != null)
                    Text(
                      'Positive expires after ${budget.schedule.carryOverLimit} periods',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  if (currentPeriodIdx > 0) ...[
                    Text(
                      '  • from prev: ${budget.formatCurrency(carryFromPrev, decimalDigits: 0)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    Text(
                      '  • from older: ${budget.formatCurrency(carryFromOlder, decimalDigits: 0)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ]
                ],
              ),
              Text(budget.formatCurrency(budget.carryOver),
                  style: TextStyle(
                      fontSize: 16,
                      color: budget.carryOver >= 0 ? Colors.green : Colors.red))
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Actual Budget', style: TextStyle(fontSize: 16)),
              Text(budget.formatCurrency(budget.totalBudget),
                  style: const TextStyle(fontSize: 18))
            ],
          ),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Spent', style: TextStyle(fontSize: 16)),
                const Text('This Period',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            Text(budget.formatCurrency(budget.balance),
                style: const TextStyle(fontSize: 16))
          ],
        )
      ],
    );
  }

  List<Widget> _buildGroupedExpenses(
      Budget budget, List<Expense> expenses, SettingsProvider settings) {
    List<Widget> widgets = [];

    final timeFormat = settings.getTimeFormat();
    final dateFormat = settings.getDateFormat();
    final detailFormat = settings.getDateFormat(includeTime: true);

    // Group expenses by period index
    Map<int, List<Expense>> groups = {};
    for (var e in expenses) {
      int idx =
          budget.getPeriodIndex(e.dateTime, locationName: settings.timezone);
      groups.putIfAbsent(idx, () => []).add(e);
    }

    // Get sorted period indices descending (newest periods first)
    // Now including ALL periods up to current
    int currentPeriodIdx =
        budget.getPeriodsElapsed(locationName: settings.timezone) - 1;
    List<int> indices = List.generate(currentPeriodIdx + 1, (i) => i)
      ..sort((a, b) => b.compareTo(a));

    // Calculate spent per period to determine carry over history
    Map<int, int> periodSpentMap = {};
    for (var e in expenses) {
      int idx =
          budget.getPeriodIndex(e.dateTime, locationName: settings.timezone);
      periodSpentMap[idx] = (periodSpentMap[idx] ?? 0) + e.amount;
    }

    for (int idx in indices) {
      final periodStartUtc =
          budget.getPeriodStart(idx, locationName: settings.timezone);
      final periodStartDisplay = settings.toSelectedTimezone(periodStartUtc);

      // Determine how granular the date/time display should be
      String periodLabel;
      if (budget.schedule.periodicity == Periodicity.seconds ||
          budget.schedule.periodicity == Periodicity.minutes ||
          budget.schedule.periodicity == Periodicity.hours) {
        periodLabel = detailFormat.format(periodStartDisplay);
      } else {
        periodLabel = dateFormat.format(periodStartDisplay);
      }

      // Calculate carry over into THIS specific period
      int carryOverIntoThisPeriod = 0;
      int carryFromPrev = 0;
      int carryFromOlder = 0;
      int expiredInThisPeriod = 0;
      if (budget.schedule.carryOver) {
        int currentCarryIn = 0;
        int B = budget.schedule.budget;
        int? limit = budget.schedule.carryOverLimit;

        for (int j = 0; j <= idx; j++) {
          int avail = B + currentCarryIn;
          int spent = periodSpentMap[j] ?? 0;
          int remaining = avail - spent;

          if (j == idx) {
            carryOverIntoThisPeriod = currentCarryIn;
            if (j > 0) {
              carryFromPrev = B - (periodSpentMap[j - 1] ?? 0);
              carryFromOlder = currentCarryIn - carryFromPrev;
            }
          }

          // Calculate carryIn for j+1
          int nextCarryIn = 0;
          int k = j + 1;
          int n = limit ?? k;
          if (n > k) n = k;
          int firstIdx = k - n;

          int totalAllowanceInWindow = n * B;
          int totalSpentInWindow = 0;
          for (int i = firstIdx; i < k; i++) {
            totalSpentInWindow += periodSpentMap[i] ?? 0;
          }
          int windowCarryIn = totalAllowanceInWindow - totalSpentInWindow;

          if (remaining < 0) {
            nextCarryIn = remaining;
          } else {
            nextCarryIn = remaining < windowCarryIn
                ? remaining
                : (windowCarryIn > 0 ? windowCarryIn : 0);
          }

          if (j == idx) {
            expiredInThisPeriod = remaining - nextCarryIn;
          }
          currentCarryIn = nextCarryIn;
        }
      }

      // Period Header
      widgets.add(Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        margin: const EdgeInsets.only(top: 8, bottom: 2),
        color: Colors.grey.shade200,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Period $idx ($periodLabel)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (budget.schedule.carryOver && idx > 0)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Carry in: ${budget.formatCurrency(carryOverIntoThisPeriod)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: carryOverIntoThisPeriod >= 0
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                  ),
                  Text(
                    '  • from prev: ${budget.formatCurrency(carryFromPrev, decimalDigits: 0)}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  Text(
                    '  • from older: ${budget.formatCurrency(carryFromOlder, decimalDigits: 0)}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  if (expiredInThisPeriod > 0)
                    Text(
                      'Expired: ${budget.formatCurrency(expiredInThisPeriod)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.blue,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ));

      // Expenses in this period (newest first)
      final periodExpenses = groups[idx] ?? [];
      if (periodExpenses.isEmpty) {
        widgets.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('No expenses in this period',
                style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey)),
          ),
        ));
      } else {
        periodExpenses.sort((a, b) => b.dateTime.compareTo(a.dateTime));
        for (var e in periodExpenses) {
          final expenseDisplayTime = settings.toSelectedTimezone(e.dateTime);
          widgets.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${timeFormat.format(expenseDisplayTime)} (${dateFormat.format(expenseDisplayTime)})',
                  style: const TextStyle(fontSize: 15),
                ),
                Text(
                  budget.formatCurrency(e.amount),
                  style: const TextStyle(fontSize: 15),
                )
              ],
            ),
          ));
        }
      }
    }
    return widgets;
  }

  void _addExpense(Budget budget) async {
    double? expenseAmount;
    final expense = await showDialog<double>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return SimpleDialog(
            title: const Text('Add expense'),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: TextFormField(
                  inputFormatters: [_expenseCurrencyFormatter],
                  onChanged: (value) => setDialogState(() => expenseAmount =
                      _expenseCurrencyFormatter.getUnformattedValue().toDouble()),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: false),
                  decoration: const InputDecoration(
                    border: UnderlineInputBorder(),
                    labelText: 'Amount',
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SimpleDialogOption(
                    onPressed: () {
                      Navigator.pop(context, null);
                    },
                    child: const Text('Close'),
                  ),
                  SimpleDialogOption(
                    onPressed: () {
                      if (expenseAmount != null && expenseAmount! > 0) {
                        Navigator.pop(context, expenseAmount);
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              )
            ],
          );
        });
      },
    );
    if (expense != null) {
      int expenseMicros = (expense * 1000000).round();
      await dbService.insertExpense(Expense(
          budget: budget.id!,
          amount: expenseMicros,
          dateTime: DateTime.timestamp()));
      final settings = context.read<SettingsProvider>();
      await dbService.updateBalances(locationName: settings.timezone);
      setState(() {});
    }
  }

  bool confirmDelete = false;

  void _deleteBudget(Budget budget) async {
    final navigator = Navigator.of(context); // store the Navigator
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
            title: const Text('Delete'),
            content: const Text('Do you really want to delete this budget?'),
            actions: <Widget>[
              TextButton(
                  child: const Text('Delete!'),
                  onPressed: () {
                    setState(() => confirmDelete = true);
                    navigator.pop();
                  })
            ]);
      },
    );
    if (confirmDelete) {
      await dbService.deleteBudget(budget);
      navigator.pop();
    }
  }
}
