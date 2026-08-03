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
