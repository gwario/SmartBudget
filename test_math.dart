import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  tz.initializeTimeZones();
  final location = tz.getLocation('Europe/Berlin');
  
  // Berlin Nov 1st 2024 is UTC+1 (Winter time)
  // So Nov 1st 00:05 local is Oct 31st 23:05 UTC.
  // The test used Oct 31st 22:05 UTC -> Oct 31st 23:05 Local.
  
  final startUtc = DateTime.utc(2024, 10, 31, 22, 5);
  final startLocal = tz.TZDateTime.from(startUtc, location);
  print('Start Local: $startLocal');
  print('Start Year: ${startLocal.year}, Month: ${startLocal.month}, Day: ${startLocal.day}');

  final testDateUtc = DateTime.utc(2024, 11, 1, 10, 0);
  final testDateLocal = tz.TZDateTime.from(testDateUtc, location);
  print('Test Date Local: $testDateLocal');
  
  final startEffective = DateTime(startLocal.year, startLocal.month, startLocal.day);
  final testEffective = DateTime(testDateLocal.year, testDateLocal.month, testDateLocal.day);
  
  print('Start Effective: $startEffective');
  print('Test Effective: $testEffective');
  
  final units = (testEffective.year - startEffective.year) * 12 + (testEffective.month - startEffective.month);
  print('Units: $units');
}
