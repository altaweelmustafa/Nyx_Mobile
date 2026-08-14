import 'dart:async';
import 'dart:io' show Platform;
import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/bluetooth_device_info.dart';

/// BlueZ (Linux) profile UUIDs that mean "this device carries audio" --
/// A2DP Sink, Headset, and Handsfree. Filters out connected-but-silent
/// Bluetooth peripherals (keyboards, mice) that also show up as
/// org.bluez.Device1 objects but shouldn't show up as the routed device.
const _audioProfileUuidPrefixes = ['0000110b', '00001108', '0000111e'];

/// Polls the OS for whichever Bluetooth device audio is currently routed
/// to (if any) and classifies it (headphones / car / speaker / unknown)
/// so the UI can show a matching icon + name.
///
/// Backed by a native MethodChannel on mobile, and BlueZ over D-Bus on
/// Linux desktop:
///  - Android: BluetoothA2dp/BluetoothHeadset connected-device profile + BluetoothClass.
///  - iOS: AVAudioSession.currentRoute output port type.
///  - Linux: org.bluez.Device1 objects under the system bus, filtered to
///    ones with an audio profile UUID and Connected == true.
/// No-ops (always null) on macOS/Windows/web where there's no such hookup.
class BluetoothRouteService extends ChangeNotifier {
  static const _channel = MethodChannel('com.brager/bluetooth');
  static const _pollInterval = Duration(seconds: 4);

  BluetoothDeviceInfo? _currentDevice;
  Timer? _pollTimer;
  DBusClient? _linuxClient;

  BluetoothDeviceInfo? get currentDevice => _currentDevice;

  bool get _usesMethodChannel => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  bool get _usesLinuxDbus => !kIsWeb && Platform.isLinux;

  BluetoothRouteService() {
    if (_usesMethodChannel) {
      _refresh();
      _pollTimer = Timer.periodic(_pollInterval, (_) => _refresh());
    } else if (_usesLinuxDbus) {
      _linuxClient = DBusClient.system();
      _refreshLinux();
      _pollTimer = Timer.periodic(_pollInterval, (_) => _refreshLinux());
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

  Future<void> _refreshLinux() async {
    final client = _linuxClient;
    if (client == null) return;
    try {
      final manager = DBusRemoteObjectManager(
        client,
        name: 'org.bluez',
        path: DBusObjectPath('/'),
      );
      final objects = await manager.getManagedObjects();
      for (final interfaces in objects.values) {
        final device = interfaces['org.bluez.Device1'];
        if (device == null) continue;
        if (device['Connected']?.asBoolean() != true) continue;

        final uuids = device['UUIDs']?.asStringArray().map((u) => u.toLowerCase()) ?? const <String>[];
        final isAudioDevice = uuids.any(
          (uuid) => _audioProfileUuidPrefixes.any(uuid.startsWith),
        );
        if (!isAudioDevice) continue;

        final name = device['Name']?.asString() ?? device['Alias']?.asString() ?? 'Bluetooth Device';
        final icon = device['Icon']?.asString();
        _update(BluetoothDeviceInfo(name: name, type: BluetoothDeviceInfo.typeFromBluezIcon(icon)));
        return;
      }
      _update(null);
    } catch (_) {
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
    _linuxClient?.close();
    super.dispose();
  }
}
