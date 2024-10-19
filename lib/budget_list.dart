import 'dart:developer';
import 'dart:isolate';

import 'package:smart_budget/budget_detail.dart';
import 'package:smart_budget/budget_form.dart';
import 'package:smart_budget/persistence/database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:workmanager/workmanager.dart';

import 'persistence/model.dart';

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
    Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true,
    );
    log('Registering periodic balance calculations...');
    Workmanager().registerPeriodicTask(
      simplePeriodicTask,
      'UpdateBalancesTask',
      initialDelay: Duration.zero,
      frequency: Duration(minutes: 15),
    );
    super.initState();
  }

  @override
  void dispose() async {
    await Workmanager().cancelAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
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
                          padding: const EdgeInsets.all(5),
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

  Widget _buildCardListItemWidget(Budget budget) {
    return Card(
        child: ListTile(
      title: SafeArea(
          child: Text(budget.title,
              textAlign: TextAlign.start, overflow: TextOverflow.ellipsis)),
      subtitle: _buildProgressIndicator(budget),
      trailing: _buildBudgetStatus(budget),
      isThreeLine: true,
    ));
  }

  Widget _buildListItemWidget(Budget budget) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SafeArea(
                  child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(budget.title,
                      textAlign: TextAlign.start,
                      overflow: TextOverflow.ellipsis),
                  _buildBudgetStatus(budget)
                ],
              )),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: _buildProgressIndicator(budget),
            ),
          ],
        )),
      ],
    );
  }

  Widget _buildBudgetStatus(Budget budget) {
    final format = NumberFormat.simpleCurrency(
        locale: Localizations.localeOf(context).toString());

    if (budget.balance > budget.schedule.budget) {
      var surplusPct = (budget.balance - budget.schedule.budget) *
          100 /
          budget.schedule.budget;
      var surplus = budget.schedule.budget - budget.balance;
      return Text(
          "${surplus.toStringAsFixed(2)}${format.currencySymbol} (+${surplusPct.toStringAsFixed(2)}% over ${budget.schedule.budget.toStringAsFixed(2)}${format.currencySymbol})",
          style: const TextStyle(color: Colors.red));
    } else {
      var consumedPct = _getBudgetUtilization(budget) * 100;
      return Text(
          "${budget.balance.toStringAsFixed(2)}${format.currencySymbol} (${consumedPct.toStringAsFixed(2)}% of ${budget.schedule.budget.toStringAsFixed(2)}${format.currencySymbol})");
    }
  }

  double _getBudgetUtilization(Budget budget) {
    return budget.balance / budget.schedule.budget;
  }

  Widget _buildListItemSeparator(BuildContext context, int index) {
    return const Divider(
      color: Colors.grey,
      height: 0,
    );
  }

  Widget _buildProgressIndicator(Budget budget) {
    if (budget.balance > budget.schedule.budget) {
      var surplus = (budget.balance - budget.schedule.budget) /
          (budget.schedule.budget * 100);
      return LinearProgressIndicator(value: surplus, color: Colors.red);
    } else {
      return LinearProgressIndicator(
          value: 1.0 - _getBudgetUtilization(budget));
    }
  }
}
