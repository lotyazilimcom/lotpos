import 'dart:io';

import 'package:lospos/servisler/veritabani_reset_servisi.dart';

Future<void> main(List<String> args) async {
  final onlyTruncate = args.contains('--truncate');
  final keepBuildCache = args.contains('--skip-build-clean');

  stdout.writeln('');
  stdout.writeln('🔄 LOSPOS İlk Kurulum Yardımcısı');
  stdout.writeln(
    onlyTruncate
        ? 'Mod: Sadece şirket verilerini temizle'
        : 'Mod: Tam ilk kurulum sıfırlaması',
  );

  final servis = VeritabaniResetServisi();
  if (onlyTruncate) {
    await servis.tumSirketVeritabanlariniSifirla();
  } else {
    await servis.tamIlkKurulumSifirlamasiYap();
  }

  if (!keepBuildCache) {
    await _temizleBuildArtiklari();
  }

  stdout.writeln('');
  stdout.writeln('✅ İlk kurulum yardımı tamamlandı.');
  stdout.writeln(
    'İstersen şimdi uygulamayı yeniden derleyip açabilirsin: flutter run -d macos',
  );
}

Future<void> _temizleBuildArtiklari() async {
  stdout.writeln('');
  stdout.writeln('🧹 Build artıkları temizleniyor...');
  final projectRoot = _projectRootPath();

  final targets = <String>[
    _join(<String>[projectRoot, 'build']),
    _join(<String>[projectRoot, '.dart_tool', 'flutter_build']),
    '/Users/nasip/Desktop/lotpos/build',
  ];

  for (final path in targets) {
    await _deletePath(path);
  }

  final oldRoot = Directory('/Users/nasip/Desktop/lotpos');
  if (oldRoot.existsSync()) {
    try {
      final children = oldRoot.listSync(followLinks: false);
      if (children.isEmpty) {
        await oldRoot.delete();
        stdout.writeln('   🔹 Silindi -> ${oldRoot.path}');
      }
    } catch (e) {
      stdout.writeln('   ⚠️ Eski klasör silinemedi -> ${oldRoot.path} ($e)');
    }
  }
}

Future<void> _deletePath(String path) async {
  final entityType = FileSystemEntity.typeSync(path, followLinks: false);
  try {
    switch (entityType) {
      case FileSystemEntityType.notFound:
        return;
      case FileSystemEntityType.file:
      case FileSystemEntityType.link:
        await File(path).delete();
        stdout.writeln('   🔹 Silindi -> $path');
        return;
      case FileSystemEntityType.directory:
        await Directory(path).delete(recursive: true);
        stdout.writeln('   🔹 Silindi -> $path');
        return;
      case FileSystemEntityType.unixDomainSock:
      case FileSystemEntityType.pipe:
        return;
    }
  } catch (e) {
    stdout.writeln('   ⚠️ Silinemedi -> $path ($e)');
  }
}

String _projectRootPath() {
  final scriptFile = File.fromUri(Platform.script);
  return scriptFile.parent.parent.path;
}

String _join(List<String> parts) {
  final cleaned = <String>[];
  for (var i = 0; i < parts.length; i++) {
    final raw = parts[i].trim();
    if (raw.isEmpty) continue;
    if (i == 0) {
      cleaned.add(raw.replaceAll(RegExp(r'[\\/]+$'), ''));
    } else {
      cleaned.add(raw.replaceAll(RegExp(r'^[\\/]+|[\\/]+$'), ''));
    }
  }
  return cleaned.join(Platform.pathSeparator);
}
