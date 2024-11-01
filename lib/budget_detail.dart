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
  final _budgetCurrencyFormatter = CurrencyTextInputFormatter.currency(
      locale: Platform.localeName,
      enableNegative: false,
      decimalDigits: 0,
      minValue: 0);

  @override
  Widget build(BuildContext context) {
    final budget = ModalRoute.of(context)!.settings.arguments as Budget;
    final expenseDateTimeFormat =
        DateFormat('yyyy MMMM, dd. (EEEE)', Platform.localeName);
    return Scaffold(
        appBar: AppBar(
            leading: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, color: Colors.black)),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            title: SafeArea(
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                  Flexible(
                      child: Text(
                    budget.title,
                    overflow: TextOverflow.ellipsis,
                  )),
                  if (budget.schedule.carryOver)
                    const Icon(Icons.switch_access_shortcut_add)
                ]))),
        body: Center(
            child: Padding(
                padding: const EdgeInsets.all(10),
                child: SafeArea(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 15),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Budget'),
                                Text(_budgetCurrencyFormatter
                                    .formatDouble(budget.schedule.budget))
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Balance'),
                                Text(_budgetCurrencyFormatter
                                    .formatDouble(budget.balance))
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
                              return SafeArea(
                                  child: Column(
                                      children: snapshot.data!
                                          .map((e) => Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(expenseDateTimeFormat
                                                      .format(e.dateTime)),
                                                  Text(_expenseCurrencyFormatter
                                                      .formatDouble(e.amount))
                                                ],
                                              ))
                                          .toList()));
                            }
                            return const Center(child: Text('Error.'));
                          }),
                    ])))),
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
  }

  late double expenseAmount;

  void _addExpense(Budget budget) async {
    final expense = await showDialog<double>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('Add expense'),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: TextFormField(
                inputFormatters: [_expenseCurrencyFormatter],
                onChanged: (value) => setState(() => expenseAmount =
                    _expenseCurrencyFormatter.format
                        .tryParse(value)!
                        .toDouble()),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: false),
                validator: (value) {
                  if (value == null ||
                      _expenseCurrencyFormatter.format.tryParse(value) ==
                          null ||
                      _expenseCurrencyFormatter.format.tryParse(value)! < 1) {
                    return 'Value must not be blank nor negative!';
                  }
                  return null;
                },
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
                    Navigator.pop(context, expenseAmount);
                  },
                  child: const Text('Save'),
                ),
              ],
            )
          ],
        );
      },
    );
    if (expense != null) {
      budget.balance += expense;
      await dbService.insertExpense(Expense(
          budget: budget.id!, amount: expense, dateTime: DateTime.timestamp()));
      await dbService.saveBudget(budget);
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
