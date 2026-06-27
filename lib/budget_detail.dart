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
        decimalDigits: 0,
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
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editTitle(budget),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_forever),
                      onPressed: () => _deleteBudget(budget),
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
                              _buildWaterfallHeader(budget, expenses, settings),
                              const SizedBox(height: 10),
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
              floatingActionButton: FloatingActionButton(
                onPressed: () => _addExpense(budget),
                tooltip: 'Add',
                child: const Icon(Icons.monetization_on),
              ));
        });
  }

  Widget _buildWaterfallHeader(
      Budget budget, List<Expense> expenses, SettingsProvider settings) {
    int currentPeriodIdx =
        budget.getPeriodsElapsed(locationName: settings.timezone) - 1;

    int carryInFromPast = 0;
    int carryFromPrev = 0;
    int carryFromOlder = 0;
    int n = 0;

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

      n = limit ?? currentPeriodIdx;
      if (n > currentPeriodIdx) n = currentPeriodIdx;

      for (int j = 0; j <= currentPeriodIdx; j++) {
        if (j == currentPeriodIdx) {
          carryInFromPast = currentCarryIn;
          if (j > 0) {
            carryFromPrev = B - (periodSpentMap[j - 1] ?? 0);
            carryFromOlder = currentCarryIn - carryFromPrev;
          }
        }

        // Calculate carryIn for j+1
        int nextCarryIn = 0;
        int k = j + 1;
        int winSize = limit ?? k;
        if (winSize > k) winSize = k;
        int firstIdx = k - winSize;
        int totalAllowanceInWindow = winSize * B;
        int totalSpentInWindow = 0;
        for (int i = firstIdx; i < k; i++) {
          totalSpentInWindow += periodSpentMap[i] ?? 0;
        }
        int windowCarryIn = totalAllowanceInWindow - totalSpentInWindow;

        int spent = periodSpentMap[j] ?? 0;
        int remaining = (B + currentCarryIn) - spent;

        if (remaining < 0) {
          currentCarryIn = remaining;
        } else {
          currentCarryIn = remaining < windowCarryIn
              ? remaining
              : (windowCarryIn > 0 ? windowCarryIn : 0);
        }
      }
    }

    final baseBudget = budget.schedule.budget;
    final totalAvailable = baseBudget + carryInFromPast;
    final spentThisPeriod = budget.balance;
    final currentlyLeft = totalAvailable - spentThisPeriod;
    int totalSpent = expenses.fold(0, (sum, e) => sum + e.amount);
    int elapsed = budget.getPeriodsElapsed(locationName: settings.timezone);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildWaterfallRow(
            'Base Budget',
            budget.formatCurrency(baseBudget),
            icon: Icons.flag_outlined,
            subLabel: budget.schedule.periodLabel,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                    child: Divider(
                        color: Colors.blueGrey.shade200, thickness: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('CURRENT',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.blueGrey.shade300,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2)),
                ),
                Expanded(
                    child: Divider(
                        color: Colors.blueGrey.shade200, thickness: 1)),
              ],
            ),
          ),
          _buildWaterfallRow(
            carryInFromPast >= 0 ? 'Surplus from Past' : 'Deficit from Past',
            '${carryInFromPast >= 0 ? "+" : ""} ${budget.formatCurrency(carryInFromPast)}',
            valueColor: carryInFromPast >= 0 ? Colors.green : Colors.red,
            icon: Icons.history,
            subLabel: 'from ${budget.schedule.getDurationLabel(n)}',
          ),
          const Divider(),
          _buildWaterfallRow(
            'Available Now',
            budget.formatCurrency(totalAvailable),
            icon: Icons.account_balance_wallet_outlined,
          ),
          _buildWaterfallRow(
            'Spent so far',
            "- ${budget.formatCurrency(spentThisPeriod)}",
            icon: Icons.shopping_cart_outlined,
          ),
          const Divider(),
          _buildWaterfallRow(
            currentlyLeft >= 0 ? 'Remaining' : 'Overspent',
            budget.formatCurrency(currentlyLeft),
            valueColor: currentlyLeft >= 0 ? Colors.blue : Colors.red,
            icon: Icons.summarize_outlined,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                    child: Divider(
                        color: Colors.blueGrey.shade200, thickness: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('TOTALS',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.blueGrey.shade300,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2)),
                ),
                Expanded(
                    child: Divider(
                        color: Colors.blueGrey.shade200, thickness: 1)),
              ],
            ),
          ),
          _buildWaterfallRow(
            'Total Spent',
            budget.formatCurrency(totalSpent),
            icon: Icons.summarize_outlined,
            subLabel: 'Since start',
          ),
          if (budget.totalExpired > 0)
            _buildWaterfallRow(
              'Savings Vault',
              budget.formatCurrency(budget.totalExpired),
              valueColor: Colors.blue.shade700,
              icon: Icons.savings_outlined,
              subLabel: 'protected from overspending',
            ),
          _buildWaterfallRow(
            'Duration',
            '$elapsed periods',
            icon: Icons.timer_outlined,
            subLabel: 'running since creation',
          ),
        ],
      ),
    );
  }

  Widget _buildWaterfallRow(String label, String value,
      {Color? valueColor,
      bool isBold = false,
      IconData? icon,
      String? subLabel}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    if (icon != null)
                      Icon(icon, size: 18, color: Colors.blueGrey),
                    if (icon != null) const SizedBox(width: 8),
                    Flexible(
                      child: Text(label,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                isBold ? FontWeight.bold : FontWeight.normal,
                          )),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                    color: valueColor,
                  )),
            ],
          ),
          if (subLabel != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 26),
                child: Text(subLabel,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ),
            ),
        ],
      ),
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
      int expiredInThisPeriod = 0;
      int limitCount = budget.schedule.carryOverLimit ?? (idx + 1);

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
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Period $idx',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        periodLabel,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (budget.schedule.carryOver && idx > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Rollover from $limitCount periods: ${budget.formatCurrency(carryOverIntoThisPeriod)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: carryOverIntoThisPeriod >= 0
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                      if (expiredInThisPeriod > 0)
                        Text(
                          'Moved to Vault: ${budget.formatCurrency(expiredInThisPeriod)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
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
          widgets.add(InkWell(
            onLongPress: () => _deleteExpense(budget, e),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${dateFormat.format(expenseDisplayTime)} ${timeFormat.format(expenseDisplayTime)}',
                    style: const TextStyle(fontSize: 15),
                  ),
                  Text(
                    budget.formatCurrency(e.amount),
                    style: const TextStyle(fontSize: 15),
                  )
                ],
              ),
            ),
          ));
        }
      }
    }
    return widgets;
  }

  void _addExpense(Budget budget) async {
    double? expenseAmount;
    final formatter = CurrencyTextInputFormatter.currency(
        name: budget.schedule.currencyCode,
        enableNegative: false,
        decimalDigits: 0,
        minValue: 1);

    final expense = await showDialog<double>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return SimpleDialog(
            title: Text('Add expense (${budget.schedule.currencyCode})'),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: TextFormField(
                  inputFormatters: [formatter],
                  onChanged: (value) => setDialogState(() => expenseAmount =
                      formatter.getUnformattedValue().toDouble()),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: false, signed: false),
                  decoration: InputDecoration(
                    border: const UnderlineInputBorder(),
                    labelText: 'Amount (${budget.schedule.currencyCode})',
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
                      if (expenseAmount != null && expenseAmount! >= 1) {
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

  void _editTitle(Budget budget) async {
    final controller = TextEditingController(text: budget.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Title'),
        content: TextFormField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Budget Title'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Save')),
        ],
      ),
    );

    if (newTitle != null && newTitle.trim().isNotEmpty) {
      budget.title = newTitle.trim();
      await dbService.saveBudget(budget);
      setState(() {});
    }
  }

  void _deleteExpense(Budget budget, Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to remove this expense?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      await dbService.deleteExpense(expense);
      if (mounted) {
        final settings = context.read<SettingsProvider>();
        await dbService.updateBalances(locationName: settings.timezone);
        setState(() {});
      }
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
