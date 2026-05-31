import 'dart:io';

import 'package:smart_budget/persistence/database.dart';
import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'persistence/model.dart';

class BudgetDetail extends StatefulWidget {
  const BudgetDetail({super.key});

  @override
  State<StatefulWidget> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetDetail> {
  final dbService = DatabaseService();
  final _expenseCurrencyFormatter = CurrencyTextInputFormatter.currency(
      locale: Platform.localeName,
      enableNegative: false,
      decimalDigits: 2,
      minValue: 0);

  @override
  Widget build(BuildContext context) {
    final budgetArg = ModalRoute.of(context)!.settings.arguments as Budget;
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
                        await dbService.updateBalances();
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
                      child: SingleChildScrollView(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 15),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Base Budget'),
                                    Text('${budget.formatCurrency(budget.schedule.budget)} ${budget.schedule.periodLabel}')
                                  ],
                                ),
                                if (budget.schedule.carryOver) ...[
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Carry Over'),
                                      Text(budget.formatCurrency(budget.carryOver),
                                          style: TextStyle(
                                              color: budget.carryOver >= 0
                                                  ? Colors.green
                                                  : Colors.red))
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Actual Budget'),
                                      Text(budget.formatCurrency(budget.totalBudget),
                                          style: const TextStyle(fontWeight: FontWeight.bold))
                                    ],
                                  ),
                                ],
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Spent (This Period)'),
                                    Text(budget.formatCurrency(budget.balance))
                                  ],
                                )
                              ],
                            ),
                          ),
                          FutureBuilder<List<Expense>>(
                              future: dbService.getExpenses(budget.id!),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }
                                if (snapshot.hasData) {
                                  if (snapshot.data!.isEmpty) {
                                    return const Center(
                                        child: Text('No expenses yet.'));
                                  }
                                  return Column(
                                      children: _buildGroupedExpenses(
                                          budget, snapshot.data!));
                                }
                                return const Center(child: Text('Error.'));
                              }),
                        ]),
                      ))),
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

  List<Widget> _buildGroupedExpenses(Budget budget, List<Expense> expenses) {
    List<Widget> widgets = [];

    final timeFormat = DateFormat('HH:mm:ss');
    final dateFormat = DateFormat('yyyy-MM-dd');
    final detailFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    // Group expenses by period index
    Map<int, List<Expense>> groups = {};
    for (var e in expenses) {
      int idx = budget.getPeriodIndex(e.dateTime);
      groups.putIfAbsent(idx, () => []).add(e);
    }

    // Get sorted period indices descending (newest periods first)
    // Now including ALL periods up to current
    int currentPeriodIdx = budget.periodsElapsed - 1;
    List<int> indices = List.generate(currentPeriodIdx + 1, (i) => i)..sort((a, b) => b.compareTo(a));

    // Calculate spent per period to determine carry over history
    Map<int, int> periodSpentMap = {};
    for (var e in expenses) {
      int idx = budget.getPeriodIndex(e.dateTime);
      periodSpentMap[idx] = (periodSpentMap[idx] ?? 0) + e.amount;
    }

    for (int idx in indices) {
      final periodStart = budget.getPeriodStart(idx);
      
      // Determine how granular the date/time display should be
      String periodLabel;
      if (budget.schedule.periodicity == Periodicity.seconds || 
          budget.schedule.periodicity == Periodicity.minutes ||
          budget.schedule.periodicity == Periodicity.hours) {
        periodLabel = detailFormat.format(periodStart.toLocal());
      } else {
        periodLabel = dateFormat.format(periodStart.toLocal());
      }

      // Calculate carry over into THIS specific period
      int carryOverIntoThisPeriod = 0;
      if (budget.schedule.carryOver) {
        int totalAllowanceBefore = idx * budget.schedule.budget;
        int totalSpentBefore = 0;
        for (var entry in periodSpentMap.entries) {
          if (entry.key < idx) {
            totalSpentBefore += entry.value;
          }
        }
        carryOverIntoThisPeriod = totalAllowanceBefore - totalSpentBefore;
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
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            if (budget.schedule.carryOver)
              Text(
                'Carry in: ${budget.formatCurrency(carryOverIntoThisPeriod)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: carryOverIntoThisPeriod >= 0
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                ),
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
            child: Text('No expenses in this period', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey)),
          ),
        ));
      } else {
        periodExpenses.sort((a, b) => b.dateTime.compareTo(a.dateTime));
        for (var e in periodExpenses) {
          widgets.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${timeFormat.format(e.dateTime.toLocal())} (${dateFormat.format(e.dateTime.toLocal())})',
                  style: const TextStyle(fontSize: 13),
                ),
                Text(
                  budget.formatCurrency(e.amount),
                  style: const TextStyle(fontSize: 13),
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
                      _expenseCurrencyFormatter.format
                          .tryParse(value)
                          ?.toDouble()),
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
          budget: budget.id!, amount: expenseMicros, dateTime: DateTime.timestamp()));
      await dbService.updateBalances();
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
