import 'dart:typed_data';

/// Minimal byte-blob persistence abstraction so the repository can be
/// unit-tested with an in-memory fake (no platform channels in tests).
abstract interface class IFileStore {
  /// Returns the stored bytes, or null if nothing has been written yet.
  Future<Uint8List?> read();

  Future<void> write(Uint8List bytes);

  Future<void> delete();
}
