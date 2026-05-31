import 'dart:developer';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:smart_budget/budget_detail.dart';
import 'package:smart_budget/budget_form.dart';
import 'package:smart_budget/persistence/database.dart';
import 'package:workmanager/workmanager.dart';

import 'persistence/model.dart';
import 'theme.dart';

const simplePeriodicTask = 'at.ameise.smart_budget.task.updateBalances';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final dbService = DatabaseService();
    log('Processing task...');
    await dbService.updateBalances();
    log('Done!');
    return Future.value(true);
  });
}

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key, required this.title});

  final String title;

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  final dbService = DatabaseService();
  final checkBudgetsPort = ReceivePort();

  void _addBudget() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => const BudgetForm()));
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    dbService.updateBalances().then((_) => setState(() {}));
    Workmanager().initialize(
      callbackDispatcher,
    );
    log('Registering periodic balance calculations...');
    Workmanager().registerPeriodicTask(
      simplePeriodicTask,
      'UpdateBalancesTask',
      initialDelay: const Duration(minutes: 1),
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  @override
  void dispose() {
    // Removed cancelAll() to allow task to run in background
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await dbService.updateBalances();
              setState(() {});
            },
          )
        ],
      ),
      body: FutureBuilder<List<Budget>>(
          future: dbService.getBudgets(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasData) {
              if (snapshot.data!.isEmpty) {
                return const Center(child: Text('No budgets yet.'));
              }
              return ListView.separated(
                  separatorBuilder: _buildListItemSeparator,
                  itemBuilder: (BuildContext context, int index) {
                    var budget = snapshot.data![index];
                    return InkWell(
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (context) => const BudgetDetail(),
                                settings: RouteSettings(arguments: budget)),
                          );
                          setState(() {});
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 15, vertical: 10),
                          child: _buildListItemWidget(budget),
                          // child: _buildCardListItemWidget(budget),
                        ));
                  },
                  itemCount: snapshot.data!.length);
            }
            return const Center(child: Text('Error.'));
          }),
      floatingActionButton: FloatingActionButton(
        onPressed: _addBudget,
        tooltip: 'Add',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  Widget _buildListItemWidget(Budget budget) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                  child: Text(
                budget.title,
                textAlign: TextAlign.start,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: budgetLabelFontSize,
                    fontWeight: FontWeight.bold),
              )),
              _buildBudgetStatus(budget),
            ],
          ),
        ),
        _buildProgressIndicator(budget),
      ],
    );
  }

  Widget _buildBudgetStatus(Budget budget) {
    final utilization = budget.utilization;
    final totalBudget = budget.totalBudget;
    final carryOver = budget.carryOver;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${budget.formatCurrency(budget.balance, decimalDigits: 0)} used of ${budget.formatCurrency(totalBudget, decimalDigits: 0)} ${budget.schedule.periodLabelShort}',
          style: TextStyle(
            fontSize: budgetLabelFontSize,
            color: utilization > 1.0 ? Colors.red : Colors.black,
          ),
        ),
        if (budget.schedule.carryOver)
          Text(
            '(${carryOver >= 0 ? "+" : ""}${budget.formatCurrency(carryOver, decimalDigits: 0)} from past periods)',
            style: TextStyle(
              fontSize: budgetLabelFontSize - 4,
              color: carryOver >= 0 ? Colors.green : Colors.orange,
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }

  Widget _buildListItemSeparator(BuildContext context, int index) {
    return const Divider(
      color: Colors.grey,
      height: 0,
    );
  }

  Widget _buildProgressIndicator(Budget budget) {
    final utilization = budget.utilization;
    if (utilization > 1.0) {
      return LinearProgressIndicator(
        value: (utilization - 1.0).clamp(0.0, 1.0),
        color: Colors.red,
        minHeight: balanceStatusBarHeight,
        borderRadius: balanceStatusBarBorderRadius,
      );
    } else {
      return LinearProgressIndicator(
        value: 1.0 - utilization,
        minHeight: balanceStatusBarHeight,
        borderRadius: balanceStatusBarBorderRadius,
      );
    }
  }
}
