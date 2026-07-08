import 'dart:io';

import 'package:dose_wise/src/features/stats/services/pdf/pdf_fonts.dart';

PdfFontBytes? _cache;

/// Loads the Inter faces straight from the monorepo font files, so PDF
/// tests stay pure Dart — no asset bundle, no platform channels.
PdfFontBytes loadTestFonts() {
  final cached = _cache;
  if (cached != null) return cached;

  const dir = '../../packages/core_theme/fonts';
  return _cache = PdfFontBytes(
    regular: File('$dir/Inter-Regular.ttf').readAsBytesSync(),
    semiBold: File('$dir/Inter-SemiBold.ttf').readAsBytesSync(),
    bold: File('$dir/Inter-Bold.ttf').readAsBytesSync(),
  );
}
