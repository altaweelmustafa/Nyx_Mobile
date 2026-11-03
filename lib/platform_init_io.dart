import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart' as pkg_ffi;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Native-only startup work, kept out of main.dart so the web build never
/// imports dart:ffi (see platform_init_web.dart for the web side).
Future<void> initPlatform() async {
  // sqflite only talks to the platform's native SQLite on Android/iOS/macOS;
  // Linux/Windows need the FFI-backed implementation instead.
  if (Platform.isLinux || Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  if (Platform.isLinux) {
    await _ensureFfmpegTmpDir();
  }
}

/// libmpv's ffmpeg backend (used for the Linux audio backend) resolves
/// its on-disk stream cache directory the same way any C program would --
/// $TMPDIR, falling back to /tmp -- which can be unset or unwritable
/// depending on how the app was launched, producing a repeating
/// "lavf: Failed to create file cache" error on every track and, after
/// enough of those pile up, a demuxer that stops responding to play/pause.
/// Pointing TMPDIR at the app's own (guaranteed-writable) temp dir before
/// the audio backend initializes sidesteps that entirely.
Future<void> _ensureFfmpegTmpDir() async {
  final dir = await getTemporaryDirectory();
  await dir.create(recursive: true);

  final setenv = ffi.DynamicLibrary.process()
      .lookupFunction<
        ffi.Int32 Function(
          ffi.Pointer<pkg_ffi.Utf8>,
          ffi.Pointer<pkg_ffi.Utf8>,
          ffi.Int32,
        ),
        int Function(ffi.Pointer<pkg_ffi.Utf8>, ffi.Pointer<pkg_ffi.Utf8>, int)
      >('setenv');

  final name = 'TMPDIR'.toNativeUtf8();
  final value = dir.path.toNativeUtf8();
  try {
    setenv(name, value, 1);
  } finally {
    pkg_ffi.calloc.free(name);
    pkg_ffi.calloc.free(value);
  }
}
