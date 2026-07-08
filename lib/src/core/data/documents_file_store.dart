import 'dart:io';
import 'dart:typed_data';

import 'package:dose_wise/src/core/data/i_file_store.dart';
import 'package:path_provider/path_provider.dart';

/// Stores the encrypted vault blob as a single file in the application
/// documents directory. Writes go through a temp file + rename so a crash
/// mid-write cannot corrupt the existing vault.
final class DocumentsFileStore implements IFileStore {
  DocumentsFileStore({this.fileName = 'dosewise.vault'});

  final String fileName;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  @override
  Future<Uint8List?> read() async {
    final file = await _file();
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  @override
  Future<void> write(Uint8List bytes) async {
    final file = await _file();
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(file.path);
  }

  @override
  Future<void> delete() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  }
}
