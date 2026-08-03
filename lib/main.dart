import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'theme/app_theme.dart';
import 'screens/start_screen.dart';
import 'services/audio_player_service.dart';
import 'services/bluetooth_route_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

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
      title: 'Brager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const StartScreen(),
    );
  }
}
