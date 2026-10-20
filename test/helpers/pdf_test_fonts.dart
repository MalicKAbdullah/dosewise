import 'dart:convert';
import 'dart:io';

import 'package:dose_wise/src/features/stats/services/pdf/pdf_fonts.dart';

PdfFontBytes? _cache;

/// Loads the Mona Sans faces from the `core_theme` font files, so PDF tests
/// stay pure Dart — no asset bundle, no platform channels. The package
/// location comes from the resolved package config, which is correct for a
/// path override and for a git dependency alike.
PdfFontBytes loadTestFonts() {
  final cached = _cache;
  if (cached != null) return cached;

  final dir = _coreThemeFontsDir();
  return _cache = PdfFontBytes(
    regular: File('$dir/MonaSans-Regular.ttf').readAsBytesSync(),
    semiBold: File('$dir/MonaSans-SemiBold.ttf').readAsBytesSync(),
    bold: File('$dir/MonaSans-Bold.ttf').readAsBytesSync(),
  );
}

String _coreThemeFontsDir() {
  final config = File('.dart_tool/package_config.json');
  final packages = (jsonDecode(config.readAsStringSync())
      as Map<String, dynamic>)['packages'] as List<dynamic>;
  final theme = packages.cast<Map<String, dynamic>>().singleWhere(
        (p) => p['name'] == 'core_theme',
      );
  final root = config.parent.uri.resolve(theme['rootUri'] as String);
  return '${root.toFilePath()}/fonts';
}
