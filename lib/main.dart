import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:ffi/ffi.dart' as pkg_ffi;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';
import 'theme/app_theme.dart';
import 'screens/start_screen.dart';
import 'services/audio_player_service.dart';
import 'services/bluetooth_route_service.dart';
import 'services/jam_service.dart';
import 'services/library_service.dart';
import 'services/nyx_audio_handler.dart';
import 'widgets/custom_title_bar.dart';

/// window_manager only has real desktop implementations on these three --
/// on Android/iOS it's a no-op window concept that doesn't apply.
bool get _isDesktopPlatform =>
    Platform.isLinux || Platform.isWindows || Platform.isMacOS;

/// libmpv's ffmpeg backend (used for the Linux audio backend below) resolves
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // sqflite only talks to the platform's native SQLite on Android/iOS/macOS;
  // Linux/Windows need the FFI-backed implementation instead.
  if (Platform.isLinux || Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  if (Platform.isLinux) {
    await _ensureFfmpegTmpDir();
  }

  // Linux audio backend for just_audio
  JustAudioMediaKit.ensureInitialized(
    linux: true,
    windows: false,
    android: false,
    iOS: false,
    macOS: false,
  );

  final playerService = AudioPlayerService();

  // Runs playback in a foreground service with a media notification / lock
  // screen controls, so it keeps going after the screen locks or the app is
  // backgrounded. Android only -- there's no audio_service platform backend
  // wired up for the desktop targets this app also builds for.
  if (Platform.isAndroid) {
    await AudioService.init(
      builder: () => NyxAudioHandler(playerService),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.dash.nyx.channel.audio',
        androidNotificationChannelName: 'Nyx playback',
      ),
    );
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Hides the OS-native title bar (title text, minimize/maximize/close) in
  // favor of CustomTitleBar, drawn in-app so it matches the rest of the UI
  // instead of looking like a generic GTK/Win32 window. windowButtonVisibility:
  // false additionally suppresses the native buttons on platforms (Windows)
  // that would otherwise still draw them even with the title bar hidden.
  if (_isDesktopPlatform) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1280, 720),
      minimumSize: Size(720, 480),
      center: true,
      backgroundColor: Colors.transparent,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: playerService),
        ChangeNotifierProvider(create: (_) => BluetoothRouteService()),
        ChangeNotifierProvider.value(value: LibraryService.instance),
        ChangeNotifierProvider(create: (_) => JamService(playerService)),
      ],
      child: const BragerApp(),
    ),
  );
}

class BragerApp extends StatelessWidget {
  const BragerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nyx',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      // `builder` wraps every route the Navigator ever pushes (not just
      // `home`), so the custom title bar stays pinned above the whole app
      // -- Settings, the track player, Jam, all of it -- instead of only
      // the first screen.
      builder: !_isDesktopPlatform
          ? null
          : (context, child) => Column(
                children: [
                  const CustomTitleBar(),
                  Expanded(child: child ?? const SizedBox.shrink()),
                ],
              ),
      home: const StartScreen(),
    );
  }
}
