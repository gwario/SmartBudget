import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_budget/persistence/database.dart';
import 'package:smart_budget/settings.dart';

import 'persistence/calculator.dart';
import 'persistence/model.dart';

class BudgetDetail extends StatefulWidget {
  const BudgetDetail({super.key});

  @override
  State<StatefulWidget> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetDetail> {
  final dbService = DatabaseService();

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

    final (spentThisPeriod, carryInFromPast, totalExpired, _, _) =
        BudgetCalculator.calculateBalances(
      budget: budget,
      expenses: expenses,
      currentPeriodIdx: currentPeriodIdx,
      locationName: settings.timezone,
    );

    // Calculate vault movement for the current transition
    int vaultMovement = 0;
    if (currentPeriodIdx >= 0) {
      final (_, _, _, _, expirations) =
          BudgetCalculator.calculateBalances(
        budget: budget,
        expenses: expenses,
        currentPeriodIdx: currentPeriodIdx + 1,
        locationName: settings.timezone,
      );
      vaultMovement = expirations[currentPeriodIdx] ?? 0;
    }

    int n = 0;
    if (budget.schedule.carryOver && currentPeriodIdx >= 0) {
      int? limit = budget.schedule.carryOverLimit;
      n = limit ?? currentPeriodIdx;
      if (n > currentPeriodIdx) n = currentPeriodIdx;
    }

    final baseBudget = budget.schedule.budget;
    final totalAvailable = baseBudget + carryInFromPast;
    final currentlyLeft = totalAvailable - spentThisPeriod;
    int totalSpent = expenses.fold(0, (sum, e) => sum + e.amount);
    int elapsed = budget.getPeriodsElapsed(locationName: settings.timezone);

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      color: Colors.grey.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.blueGrey.shade600),
                const SizedBox(width: 8),
                Text('CURRENT PERIOD',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.blueGrey.shade700,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _buildMetric('Allowance', budget.formatCurrency(baseBudget),
                          Icons.add_circle_outline, Colors.blueGrey.shade700),
                      const SizedBox(height: 12),
                      _buildMetric(
                          carryInFromPast >= 0 ? 'Surplus In' : 'Deficit In',
                          budget.formatCurrency(carryInFromPast),
                          Icons.history,
                          carryInFromPast >= 0 ? Colors.green : Colors.red),
                      const Divider(height: 24),
                      _buildMetric('Available', budget.formatCurrency(totalAvailable),
                          Icons.account_balance_wallet, Colors.blue.shade800,
                          isBold: true),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    children: [
                      _buildMetric('Spent', budget.formatCurrency(spentThisPeriod),
                          Icons.shopping_cart_outlined, Colors.orange.shade800),
                      const SizedBox(height: 12),
                      _buildMetric(
                          currentlyLeft >= 0 ? 'Unspent' : 'Net Overspent',
                          budget.formatCurrency(currentlyLeft.abs()),
                          Icons.timelapse,
                          currentlyLeft >= 0 ? Colors.blue : Colors.red),
                      const Divider(height: 24),
                      _buildMetric('Vault Growth', budget.formatCurrency(vaultMovement),
                          Icons.savings_outlined, Colors.green.shade600),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSmallInfo(Icons.summarize, 'Total Spent',
                      budget.formatCurrency(totalSpent)),
                  _buildSmallInfo(Icons.account_balance, 'Vault Total',
                      budget.formatCurrency(totalExpired)),
                  _buildSmallInfo(Icons.timer, 'Duration', '$elapsed periods'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(
      String label, String value, IconData icon, Color color,
      {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color.withValues(alpha: 0.7)),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600)),
          ],
        ),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 16,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: color)),
      ],
    );
  }

  Widget _buildSmallInfo(IconData icon, String label, String value) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Colors.blueGrey.shade400),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(fontSize: 10, color: Colors.blueGrey.shade500)),
          ],
        ),
        Text(value,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey.shade800)),
      ],
    );
  }

  List<Widget> _buildGroupedExpenses(
      Budget budget, List<Expense> expenses, SettingsProvider settings) {
    List<Widget> widgets = [];

    final timeFormat = settings.getTimeFormat();
    final dateFormat = settings.getDateFormat();
    final detailFormat = settings.getDateFormat(includeTime: true);

    int currentPeriodIdx =
        budget.getPeriodsElapsed(locationName: settings.timezone) - 1;

    // Get sorted period indices descending (newest periods first)
    List<int> indices = List.generate(currentPeriodIdx + 1, (i) => i)
      ..sort((a, b) => b.compareTo(a));

    // Group expenses by period index
    Map<int, List<Expense>> groups = {};
    for (var e in expenses) {
      int idx =
          budget.getPeriodIndex(e.dateTime, locationName: settings.timezone);
      groups.putIfAbsent(idx, () => []).add(e);
    }

    // Calculate ALL expirations once for the entire list
    final (_, _, _, _, allExpirations) = BudgetCalculator.calculateBalances(
      budget: budget,
      expenses: expenses,
      currentPeriodIdx: currentPeriodIdx + 1,
      locationName: settings.timezone,
    );

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

      // Calculate carry over into THIS specific period using the helper
      final (spentInPeriod, carryOverIntoThisPeriod, _, _, _) =
          BudgetCalculator.calculateBalances(
        budget: budget,
        expenses: expenses,
        currentPeriodIdx: idx,
        locationName: settings.timezone,
      );

      final expiredInThisPeriod = allExpirations[idx] ?? 0;

      final totalAvail = budget.schedule.budget + carryOverIntoThisPeriod;
      final remaining = totalAvail - spentInPeriod;

      int limitCount = budget.schedule.carryOverLimit ?? (idx + 1);
      if (limitCount > idx) limitCount = idx;

      // ExpansionTile for each period
      widgets.add(Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.shade300)),
        child: ExpansionTile(
          initiallyExpanded: idx == currentPeriodIdx,
          title: Text(
              'Period ${idx + 1}${idx == currentPeriodIdx ? " (current)" : ""}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(periodLabel, style: const TextStyle(fontSize: 12)),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Spent: ${budget.formatCurrency(spentInPeriod)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                '${remaining >= 0 ? 'Unspent' : 'Net Overspent'}: ${budget.formatCurrency(remaining.abs())}',
                style: TextStyle(
                    fontSize: 11,
                    color: remaining >= 0 ? Colors.blue : Colors.red),
              ),
              if (expiredInThisPeriod > 0)
                Text(
                  'Vaulted: ${budget.formatCurrency(expiredInThisPeriod)}',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.green.shade700,
                      fontStyle: FontStyle.italic),
                ),
            ],
          ),
          shape: const Border(),
          collapsedShape: const Border(),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Period Allowance:',
                          style: TextStyle(fontSize: 12)),
                      Text(budget.formatCurrency(budget.schedule.budget),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  if (budget.schedule.carryOver && idx > 0) ...[
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Rollover ($limitCount periods):',
                            style: const TextStyle(fontSize: 12)),
                        Text(budget.formatCurrency(carryOverIntoThisPeriod),
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: carryOverIntoThisPeriod >= 0
                                    ? Colors.green
                                    : Colors.red)),
                      ],
                    ),
                    if (expiredInThisPeriod > 0) ...[
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Moved to Savings Vault:',
                              style: TextStyle(fontSize: 12)),
                          Text(budget.formatCurrency(expiredInThisPeriod),
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700)),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            // Expenses in this period
            ..._buildExpenseList(groups[idx] ?? [], budget, settings, dateFormat, timeFormat),
            const SizedBox(height: 8),
          ],
        ),
      ));
    }
    return widgets;
  }

  List<Widget> _buildExpenseList(List<Expense> periodExpenses, Budget budget,
      SettingsProvider settings, DateFormat dateFormat, DateFormat timeFormat) {
    if (periodExpenses.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text('No expenses in this period',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
        )
      ];
    }
    periodExpenses.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return periodExpenses.map((e) {
      final expenseDisplayTime = settings.toSelectedTimezone(e.dateTime);
      return InkWell(
        onLongPress: () => _deleteExpense(budget, e),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${dateFormat.format(expenseDisplayTime)} ${timeFormat.format(expenseDisplayTime)}',
                style: const TextStyle(fontSize: 14),
              ),
              Text(
                budget.formatCurrency(e.amount),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              )
            ],
          ),
        ),
      );
    }).toList();
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
