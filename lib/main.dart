import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'config.dart';
import 'platform_init_io.dart'
    if (dart.library.js_interop) 'platform_init_web.dart';
import 'theme/app_theme.dart';
import 'models/track.dart';
import 'screens/start_screen.dart';
import 'screens/track_view_screen.dart';
import 'services/audio_player_service.dart';
import 'services/bluetooth_route_service.dart';
import 'services/deep_link_service.dart';
import 'services/discord_presence_service.dart';
import 'services/snack_presence_service.dart';
import 'services/jam_service.dart';
import 'services/library_service.dart';
import 'services/nyx_audio_handler.dart';
import 'widgets/custom_title_bar.dart';
import 'widgets/desktop_shortcuts.dart';

/// Lets DeepLinkService (and StartScreen, for the cold-start link) push a
/// screen without needing a BuildContext of their own.
final navigatorKey = GlobalKey<NavigatorState>();

void pushSharedTrack(Track track) {
  navigatorKey.currentState?.push(
    MaterialPageRoute(builder: (_) => TrackViewScreen(track: track)),
  );
}

/// window_manager only has real desktop implementations on these three --
/// on Android/iOS it's a no-op window concept that doesn't apply.
bool get _isDesktopPlatform =>
    !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initPlatform();

  // Linux/Windows audio backend for just_audio
  if (!kIsWeb) JustAudioMediaKit.ensureInitialized(
    linux: true,
    windows: true,
    android: false,
    iOS: false,
    macOS: false,
  );

  final playerService = AudioPlayerService();

  // Discord Rich Presence -- only meaningful where a Discord desktop client
  // can be running alongside brager to receive it over its local IPC socket;
  // no equivalent channel exists on Android/iOS. See DiscordPresenceService.
  if (_isDesktopPlatform) {
    DiscordPresenceService(playerService, clientId: kDiscordClientId).start();
  }

  // "Listening to Nyx" on the Snack profile -- every platform, incl. web.
  SnackPresenceService.instance.start(playerService);

  // Runs playback in a foreground service with a media notification / lock
  // screen controls, so it keeps going after the screen locks or the app is
  // backgrounded. Android only -- there's no audio_service platform backend
  // wired up for the desktop targets this app also builds for.
  if (!kIsWeb && Platform.isAndroid) {
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

  // Links tapped while the app is already running (cold-start links are
  // handled separately by StartScreen, after the tailnet gate clears).
  DeepLinkService.instance.trackStream.listen(pushSharedTrack);

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
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      // `builder` wraps every route the Navigator ever pushes (not just
      // `home`), so the custom title bar stays pinned above the whole app
      // -- Settings, the track player, Jam, all of it -- instead of only
      // the first screen.
      builder: !_isDesktopPlatform
          ? null
          : (context, child) => DesktopShortcuts(
                child: Column(
                  children: [
                    const CustomTitleBar(),
                    Expanded(child: child ?? const SizedBox.shrink()),
                  ],
                ),
              ),
      home: const StartScreen(),
    );
  }
}
