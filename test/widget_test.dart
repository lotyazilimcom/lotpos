import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:patisyov10/yardimcilar/ceviri/ceviri_servisi.dart';
import 'package:patisyov10/yardimcilar/ceviri/tr.dart';
import 'package:patisyov10/yardimcilar/ceviri/en.dart';
import 'package:patisyov10/yardimcilar/ceviri/ar.dart';

void main() {
  test('tr() core çevirileri döner', () {
    expect(tr('app.title'), isNotEmpty);
    expect(tr('app.title'), isNot('app.title'));
  });

  test('tr() bulunamayan key için fallback döner', () {
    const missingKey = '__codex_test_missing_key__';
    expect(tr(missingKey), missingKey);
  });

  test('Core çeviri key setleri birebir aynı (TR/EN/AR)', () {
    final trKeys = trCeviriler.keys.toSet();
    expect(enCeviriler.keys.toSet(), equals(trKeys));
    expect(arCeviriler.keys.toSet(), equals(trKeys));
  });

  test('Core çeviri değerleri boş olamaz (TR/EN/AR)', () {
    expect(trCeviriler.values.where((v) => v.trim().isEmpty), isEmpty);
    expect(enCeviriler.values.where((v) => v.trim().isEmpty), isEmpty);
    expect(arCeviriler.values.where((v) => v.trim().isEmpty), isEmpty);
  });

  test('Kodda kullanılan tüm statik tr("key") değerleri TR map içinde var', () {
    final keySet = trCeviriler.keys.toSet();
    final missing = <String>{};
    final trCall = RegExp("\\btr\\(\\s*(['\\\"])([^'\\\"\\n]+)\\1");

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.dart')) continue;
      final content = entity.readAsStringSync();

      for (final match in trCall.allMatches(content)) {
        final key = match.group(2) ?? '';
        if (key.isEmpty) continue;
        // Dinamik key'ler: tr('country.$code'), tr('...${x}...') gibi
        if (key.contains(r'$')) continue;
        if (!keySet.contains(key)) missing.add(key);
      }
    }

    final sorted = missing.toList()..sort();
    expect(
      sorted,
      isEmpty,
      reason: sorted.isEmpty
          ? null
          : 'Eksik çeviri key(ler)i: ${sorted.take(25).join(', ')}',
    );
  });
}
