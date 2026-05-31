import 'dart:io';

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
  final _formKey = GlobalKey<FormState>();
  final dateTimeFormat = DateFormat('EEEE dd. MMMM, yyyy', Platform.localeName);
  final _periodicityWithParam = [
    Periodicity.seconds,
    Periodicity.minutes,
    Periodicity.hours,
    Periodicity.days,
    Periodicity.weeks,
    Periodicity.months,
    Periodicity.years,
  ];

  String? _title;
  double? _budget;
  int? _periodicityParam;
  Periodicity? _periodicity;
  bool _carryOver = false;
  DateTime? _startDateTime = DateTime.now();
  final _dateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _updateDateDisplay();
  }

  void _updateDateDisplay() {
    if (_startDateTime != null) {
      _dateController.text = dateTimeFormat.format(_startDateTime!);
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final defaultCurrency = NumberFormat().currencyName ?? 'USD';
    final format = NumberFormat.simpleCurrency(
        name: defaultCurrency, decimalDigits: 0);
    final currencyFormatter = CurrencyTextInputFormatter.currency(
        name: defaultCurrency, decimalDigits: 0, enableNegative: false);
    var enabledPeriodicities = [
      Periodicity.seconds,
      Periodicity.minutes,
      Periodicity.hours,
      Periodicity.daily,
      Periodicity.weekly,
      Periodicity.monthly,
      Periodicity.yearly,
    ];
    return Scaffold(
      appBar: AppBar(
          leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, color: Colors.black)),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const SafeArea(
            child: Text('New budget'),
          )),
      body: SingleChildScrollView(
        child: Padding(
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
                        currencyFormatter.format.tryParse(value)?.toDouble()),
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
                      const Flexible(
                        child: Text(
                            'Carry over remaining budget to the next period?'),
                      ),
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
                              child: Text(e.name[0].toUpperCase() + e.name.substring(1)),
                            ))
                        .toList(),
                  ),
                  if (_periodicityWithParam.contains(_periodicity))
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: TextFormField(
                          key: ValueKey('periodParam_${_periodicity?.name}'),
                          initialValue: _periodicityParam?.toString() ?? '1',
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
                              labelText: 'Every X ${_periodicity!.name}')),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: TextFormField(
                      decoration: const InputDecoration(hintText: 'Start date'),
                      controller: _dateController,
                      readOnly: true,
                      onTap: () => showDatePicker(
                        context: context,
                        initialDate: _startDateTime ?? DateTime.now(),
                        initialEntryMode: DatePickerEntryMode.calendarOnly,
                        firstDate: DateTime(DateTime.now().year - 1),
                        lastDate: DateTime(DateTime.now().year + 1),
                      ).then((value) {
                        if (value != null) {
                          setState(() {
                            _startDateTime = value;
                            _updateDateDisplay();
                          });
                        }
                      }),
                      validator: (value) =>
                          (value != null && value.trim().isNotEmpty)
                              ? null
                              : 'Required',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState?.validate() ?? false) {
                          if (_title == null || _budget == null || _periodicity == null || _startDateTime == null) {
                            return;
                          }
                          DateTime startTime = _startDateTime!;
                          // If the user picked today, use current time instead of midnight
                          final now = DateTime.now();
                          if (startTime.year == now.year && startTime.month == now.month && startTime.day == now.day) {
                            startTime = now;
                          }

                          await dbService.insertBudget(Budget(
                              title: _title!,
                              balance: 0,
                              schedule: BudgetSchedule(
                                  carryOver: _carryOver,
                                  budget: (_budget! * 1000000).round(),
                                  periodicity: _periodicity!,
                                  periodParam: _periodicityParam,
                                  start: startTime,
                                  currencyCode: defaultCurrency)));
                          navigator.pop();
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Budget created')),
                          );
                        }
                      },
                      child: const Text('Create'),
                    ),
                  ),
                ],
              )),
        ),
      ),
    );
  }

  bool validate() {
    print(_title);
    print(_budget);
    print(_carryOver);
    print(_periodicity);
    print(_periodicityParam);

    return _title != null &&
        _title!.trim().isNotEmpty &&
        _budget != null &&
        _budget! > 0 &&
        _periodicity != null &&
        _startDateTime != null;
  }
}
