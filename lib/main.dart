import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'theme/app_theme.dart';
import 'screens/start_screen.dart';
import 'services/audio_player_service.dart';
import 'services/bluetooth_route_service.dart';
import 'services/jam_service.dart';
import 'services/library_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // sqflite only talks to the platform's native SQLite on Android/iOS/macOS;
  // Linux/Windows need the FFI-backed implementation instead.
  if (Platform.isLinux || Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Linux audio backend for just_audio
  JustAudioMediaKit.ensureInitialized(
    linux: true,
    windows: false,
    android: false,
    iOS: false,
    macOS: false,
  );

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

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AudioPlayerService()),
        ChangeNotifierProvider(create: (_) => BluetoothRouteService()),
        ChangeNotifierProvider.value(value: LibraryService.instance),
        // AudioPlayerService() always returns the same singleton instance,
        // so JamService binds to the real shared player here.
        ChangeNotifierProvider(create: (_) => JamService(AudioPlayerService())),
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
      home: const StartScreen(),
    );
  }
}
