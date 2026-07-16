import 'dart:io';

void main() {
  final lines = File('machine_analyze.txt').readAsLinesSync();
  final filesToFix = <String>{};

  for (var line in lines) {
    if (line.contains('use_build_context_synchronously')) {
      final parts = line.split('|');
      if (parts.length > 3) {
        filesToFix.add(parts[3]);
      }
    }
  }

  // ignore: avoid_print
  print('Found ${filesToFix.length} files with use_build_context_synchronously.');

  for (var filePath in filesToFix) {
    var file = File(filePath);
    if (!file.existsSync()) continue;

    var content = file.readAsStringSync();

    content = content.replaceAllMapped(
      RegExp(
          r'(await\s+[^;]+;\s+)(?:setState\(\(\)\s*=>\s*_[a-zA-Z0-9]+\s*=\s*false\);\s*)?(Navigator\.|ScaffoldMessenger\.|showDialog|showModalBottomSheet|context\.)'),
      (match) {
        if (content.substring(0, match.start).contains('if (!mounted) return;')) {
          return match.group(0)!;
        }
        return 'if (!mounted) return;\n      ';
      },
    );

    file.writeAsStringSync(content);
    // ignore: avoid_print
    print('Patched $filePath');
  }
}
