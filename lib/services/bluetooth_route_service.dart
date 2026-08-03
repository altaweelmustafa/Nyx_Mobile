import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/bluetooth_device_info.dart';

/// Polls the OS for whichever Bluetooth device audio is currently routed
/// to (if any) and classifies it (headphones / car / speaker / unknown)
/// so the UI can show a matching icon + name.
///
/// Backed by a native MethodChannel:
///  - Android: BluetoothA2dp/BluetoothHeadset connected-device profile + BluetoothClass.
///  - iOS: AVAudioSession.currentRoute output port type.
/// No-ops (always null) on desktop/web where there's no such native hookup.
class BluetoothRouteService extends ChangeNotifier {
  static const _channel = MethodChannel('com.brager/bluetooth');
  static const _pollInterval = Duration(seconds: 4);

  BluetoothDeviceInfo? _currentDevice;
  Timer? _pollTimer;

  BluetoothDeviceInfo? get currentDevice => _currentDevice;

  bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  BluetoothRouteService() {
    if (_supported) {
      _refresh();
      _pollTimer = Timer.periodic(_pollInterval, (_) => _refresh());
    }
  }

  Future<void> _refresh() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getConnectedDevice',
      );
      if (result == null) {
        _update(null);
        return;
      }
      final name = result['name'] as String? ?? 'Bluetooth Device';
      final type = BluetoothDeviceInfo.typeFromString(result['type'] as String?);
      _update(BluetoothDeviceInfo(name: name, type: type));
    } on PlatformException {
      _update(null);
    } on MissingPluginException {
      _update(null);
    }
  }

  void _update(BluetoothDeviceInfo? device) {
    if (_currentDevice?.name == device?.name && _currentDevice?.type == device?.type) {
      return;
    }
    _currentDevice = device;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
