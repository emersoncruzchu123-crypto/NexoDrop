import 'dart:convert';
import 'dart:math';

final _random = Random.secure();
String randomId() =>
    base64UrlEncode(List.generate(24, (_) => _random.nextInt(256)));
String safeName(String name, {bool windows = false}) {
  final clean = name
      .split(RegExp(r'[/\\]'))
      .last
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
      .replaceAll(RegExp(r'[. ]+$'), '');
  if (clean.isEmpty || clean == '.' || clean == '..') return 'archivo';
  var result = clean.length > 120 ? clean.substring(0, 120) : clean;
  if (windows) {
    // Truncation can expose a trailing dot/space or split a UTF-16 pair.
    final last = result.codeUnitAt(result.length - 1);
    if (last >= 0xd800 && last <= 0xdbff) {
      result = result.substring(0, result.length - 1);
    }
    result = result.replaceAll(RegExp(r'[. ]+$'), '');
    if (result.isEmpty) return 'archivo';
    final stem = result.split('.').first.trimRight();
    if (RegExp(
      r'^(CON|PRN|AUX|NUL|COM[1-9¹²³]|LPT[1-9¹²³]|CONIN\$|CONOUT\$)$',
      caseSensitive: false,
    ).hasMatch(stem)) {
      result = '_$result';
    }
  }
  return result;
}
