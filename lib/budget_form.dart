import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_budget/persistence/database.dart';
import 'package:smart_budget/settings.dart';

import 'persistence/model.dart';

class BudgetForm extends StatefulWidget {
  const BudgetForm({super.key});

  @override
  State<StatefulWidget> createState() => _BudgetFormState();
}

class _BudgetFormState extends State<BudgetForm> {
  final dbService = DatabaseService();
  final _formKey = GlobalKey<FormState>();
  final _periodicityWithParam = [
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

  final _enabledPeriodicities = [
    Periodicity.minutes,
    Periodicity.hours,
    Periodicity.daily,
    Periodicity.days,
    Periodicity.weekly,
    Periodicity.weeks,
    Periodicity.monthly,
    Periodicity.months,
    Periodicity.yearly,
    Periodicity.years,
  ];

  @override
  void initState() {
    super.initState();
    _updateDateDisplay();
  }

  void _updateDateDisplay() {
    if (_startDateTime != null) {
      final settings = context.read<SettingsProvider>();
      _dateController.text = settings.getDateFormat().format(_startDateTime!);
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  String _getPeriodicityLabel(Periodicity p) {
    switch (p) {
      case Periodicity.minutes: return 'Every X minutes';
      case Periodicity.hours: return 'Every X hours';
      case Periodicity.daily: return 'Daily';
      case Periodicity.days: return 'Every X days';
      case Periodicity.weekly: return 'Weekly';
      case Periodicity.weeks: return 'Every X weeks';
      case Periodicity.monthly: return 'Monthly';
      case Periodicity.months: return 'Every X months';
      case Periodicity.yearly: return 'Yearly';
      case Periodicity.years: return 'Every X years';
      default: return p.name[0].toUpperCase() + p.name.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final settings = context.watch<SettingsProvider>();

    final displayCurrency = settings.effectiveCurrency;
    final format =
        NumberFormat.simpleCurrency(name: displayCurrency, decimalDigits: 0);
    final currencyFormatter = CurrencyTextInputFormatter.currency(
        name: displayCurrency, decimalDigits: 0, enableNegative: false);

    final commonCurrencies = {
      'USD': 'US Dollar (\$)',
      'EUR': 'Euro (€)',
      'GBP': 'British Pound (£)',
      'JPY': 'Japanese Yen (¥)',
      'CHF': 'Swiss Franc (CHF)',
      'AUD': 'Australian Dollar (A\$)',
      'CAD': 'Canadian Dollar (C\$)',
      'CNY': 'Chinese Yuan (¥)',
      'KWD': 'Kuwaiti Dinar (KWD)',
    };

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
                    key: ValueKey('budget_input_$displayCurrency'),
                    inputFormatters: [currencyFormatter],
                    onChanged: (value) {
                      setState(() {
                        _budget =
                            currencyFormatter.getUnformattedValue().toDouble();
                      });
                    },
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: false),
                    validator: (value) {
                      if (_budget == null || _budget! <= 0) {
                        return 'Value must be greater than zero!';
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
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      border: UnderlineInputBorder(),
                      labelText: 'Periodicity',
                    ),
                    value: _periodicity?.name,
                    onChanged: (value) {
                      if (value == null) return;
                      final periodicity =
                          Periodicity.values.firstWhere((e) => e.name == value);
                      setState(() {
                        _periodicity = periodicity;
                        if (periodicity == Periodicity.monthly) {
                          _periodicityParam = 1;
                          if (_startDateTime != null) {
                            _startDateTime = DateTime(
                                _startDateTime!.year, _startDateTime!.month, 1);
                            _updateDateDisplay();
                          }
                        } else if (periodicity == Periodicity.weekly) {
                          _periodicityParam = 1;
                          if (_startDateTime != null) {
                            int targetDay;
                            if (settings.firstDayOfWeek != null) {
                              targetDay = settings.firstDayOfWeek!;
                            } else {
                              final firstDayOfWeekIndex = MaterialLocalizations.of(context).firstDayOfWeekIndex;
                              targetDay = firstDayOfWeekIndex == 0 ? 7 : firstDayOfWeekIndex;
                            }
                            final currentDay = _startDateTime!.weekday;
                            final daysToSubtract = (currentDay - targetDay + 7) % 7;
                            _startDateTime = _startDateTime!.subtract(Duration(days: daysToSubtract));
                            _updateDateDisplay();
                          }
                        } else if (periodicity == Periodicity.yearly) {
                          _periodicityParam = 1;
                          if (_startDateTime != null) {
                            _startDateTime =
                                DateTime(_startDateTime!.year, 1, 1);
                            _updateDateDisplay();
                          }
                        }
                      });
                    },
                    items: _enabledPeriodicities
                        .map((e) => DropdownMenuItem(
                              value: e.name,
                              child: Text(_getPeriodicityLabel(e)),
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
                          if (_title == null ||
                              _budget == null ||
                              _periodicity == null ||
                              _startDateTime == null) {
                            return;
                          }
                          DateTime startTime = _startDateTime!;
                          // If the user picked today, use current time instead of midnight
                          final now = DateTime.now();
                          if (startTime.year == now.year &&
                              startTime.month == now.month &&
                              startTime.day == now.day) {
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
                                  currencyCode: displayCurrency)));
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
}
