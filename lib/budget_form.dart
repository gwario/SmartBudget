import 'package:smart_budget/persistence/database.dart';
import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'persistence/model.dart';

class BudgetForm extends StatefulWidget {
  const BudgetForm({super.key});

  @override
  State<StatefulWidget> createState() => _BudgetFormState();
}

class _BudgetFormState extends State<BudgetForm> {
  final dbService = DatabaseService();
  final _formKey = GlobalKey<_BudgetFormState>();

  final _periodicityWithParam = [
    Periodicity.years,
    Periodicity.months,
    Periodicity.weeks,
    Periodicity.days
  ];

  String? _title;
  double? _budget;
  int? _periodicityParam;
  Periodicity? _periodicity;
  bool _carryOver = false;
  final DateTime _startDateTime = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final locale = Localizations.localeOf(context);
    final format = NumberFormat.simpleCurrency(locale: locale.toString());
    final currencyFormatter = CurrencyTextInputFormatter.currency(
        decimalDigits: 2, enableNegative: false);
    var enabledPeriodicities = Periodicity.values.where((val) => [Periodicity.monthly, Periodicity.yearly].contains(val));
    return Scaffold(
      appBar: AppBar(
          leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, color: Colors.black)),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const SafeArea(
            child: Text('New budget'),
          )),
      body: Padding(
        padding: const EdgeInsets.all(10),
        child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUnfocus,
            child: Column(
              children: [
                TextFormField(
                    onChanged: (value) => setState(() => _title = value),
                    decoration: const InputDecoration(
                      border: UnderlineInputBorder(),
                      labelText: 'Title',
                    )),
                TextFormField(
                  inputFormatters: [currencyFormatter],
                  onChanged: (value) => setState(() => _budget =
                      currencyFormatter.format.tryParse(value)!.toDouble()),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: false),
                  validator: (value) {
                    if (value == null ||
                        currencyFormatter.format.tryParse(value) == null ||
                        currencyFormatter.format.tryParse(value)! < 1) {
                      return 'Value must not be blank nor negative!';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    border: const UnderlineInputBorder(),
                    labelText: 'Budget in ${format.currencySymbol}',
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                        'Carry over remaining budget to the next period?'),
                    Switch(
                      value: _carryOver,
                      onChanged: (bool value) =>
                          setState(() => _carryOver = value),
                    ),
                  ],
                ),
                DropdownButtonFormField(
                  decoration: const InputDecoration(
                    border: UnderlineInputBorder(),
                    labelText: 'Periodicity',
                  ),
                  onChanged: (value) => setState(() => _periodicity =
                      enabledPeriodicities.firstWhere((e) => e.name == value)),
                  items: enabledPeriodicities
                      .map((e) => DropdownMenuItem(
                            value: e.name,
                            child: Text(e.name),
                          ))
                      .toList(),
                ),
                if (_periodicityWithParam.contains(_periodicity))
                  TextFormField(
                      autovalidateMode: AutovalidateMode.onUnfocus,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'\d'))
                      ],
                      onChanged: (value) => setState(
                          () => _periodicityParam = int.tryParse(value)),
                      validator: (value) {
                        if (value == null ||
                            int.tryParse(value) == null ||
                            int.tryParse(value)! < 1) {
                          return 'Invalid number!';
                        }
                        return null;
                      },
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: false, signed: false),
                      decoration: InputDecoration(
                          border: const UnderlineInputBorder(),
                          labelText: 'Number of ${_periodicity!.name}')),
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: InputDatePickerFormField(
                    firstDate: DateTime.now(),
                    lastDate: DateTime.utc(
                        DateTime.now().year + 1, DateTime.now().month),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // if (_formKey.currentState!.validate()) {
                    //   print("validation failed");
                    // }
                    print(_title);
                    print(_budget);
                    print(_carryOver);
                    print(_periodicity);
                    print(_periodicityParam);
                    await dbService.insertBudget(Budget(
                        title: _title!,
                        balance: 0,
                        schedule: BudgetSchedule(
                            carryOver: false,
                            budget: _budget!,
                            periodicity: _periodicity!,
                            periodParam: _periodicityParam,
                            start: DateTime.now())));
                    navigator.pop();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Processing Data')),
                    );
                  },
                  child: const Text('Create'),
                ),
              ],
            )),
      ),
    );
  }
}
