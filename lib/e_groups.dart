/// Orientacyjna grupa dodatku wg zakresu numeru E (np. "barwnik").
/// To tylko podział po numerach - faktyczna funkcja zależy od zastosowania.
String? groupForCode(String code) {
  final n = int.tryParse(RegExp(r'\d+').firstMatch(code)?.group(0) ?? '');
  if (n == null) return null;
  if (n >= 100 && n < 200) return 'barwnik';
  if (n >= 200 && n < 300) return 'konserwant';
  if (n >= 300 && n < 400) return 'przeciwutleniacz / regulator kwasowości';
  if (n >= 400 && n < 500) return 'zagęstnik / emulgator / stabilizator';
  if (n >= 500 && n < 600) return 'regulator kwasowości / przeciwzbrylający';
  if (n >= 600 && n < 700) return 'wzmacniacz smaku';
  if (n >= 900 && n < 950) return 'substancja glazurująca / gaz / pomocnicza';
  if (n >= 950 && n < 1000) return 'substancja słodząca';
  if (n >= 1400 && n < 1500) return 'skrobia modyfikowana';
  if (n >= 1000) return 'inna substancja dodatkowa';
  return null;
}
