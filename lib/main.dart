import 'dart:io';
import 'package:audio_service/audio_service.dart';
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
import 'services/nyx_audio_handler.dart';

void main() async {
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
      home: const StartScreen(),
    );
  }
}
