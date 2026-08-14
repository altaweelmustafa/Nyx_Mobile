import 'package:flutter/material.dart';

enum BtDeviceType { headphones, car, speaker, unknown }

class BluetoothDeviceInfo {
  final String name;
  final BtDeviceType type;

  const BluetoothDeviceInfo({required this.name, required this.type});

  static BtDeviceType typeFromString(String? raw) {
    switch (raw) {
      case 'headphones':
        return BtDeviceType.headphones;
      case 'car':
        return BtDeviceType.car;
      case 'speaker':
        return BtDeviceType.speaker;
      default:
        return BtDeviceType.unknown;
    }
  }

  /// Maps a BlueZ org.bluez.Device1 `Icon` property (freedesktop icon
  /// naming spec names, e.g. "audio-headphones", "audio-card") to our
  /// device type.
  static BtDeviceType typeFromBluezIcon(String? icon) {
    switch (icon) {
      case 'audio-headphones':
      case 'audio-headset':
        return BtDeviceType.headphones;
      case 'car':
        return BtDeviceType.car;
      case 'audio-card':
        return BtDeviceType.speaker;
      default:
        return BtDeviceType.unknown;
    }
  }

  IconData get icon {
    switch (type) {
      case BtDeviceType.headphones:
        return Icons.headphones;
      case BtDeviceType.car:
        return Icons.directions_car;
      case BtDeviceType.speaker:
        return Icons.speaker;
      case BtDeviceType.unknown:
        return Icons.bluetooth;
    }
  }
}
