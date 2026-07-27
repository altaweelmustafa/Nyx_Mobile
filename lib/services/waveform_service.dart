import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_waveform/just_waveform.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class WaveformService {
  WaveformService._();

  static final _cache = <String, List<double>>{};

  static Future<List<double>?> extract(
    String? assetPath, {
    int barCount = 200,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS) {
      return null;
    }

    if (assetPath == null) return null;
    if (!assetPath.startsWith('assets/')) return null;

    final cacheKey = '$assetPath:$barCount';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    try {
      final tmp = await getTemporaryDirectory();
      final filename = p.basename(assetPath);
      final audioFile = File(p.join(tmp.path, filename));

      if (!audioFile.existsSync()) {
        final bytes = await rootBundle.load(assetPath);
        await audioFile.writeAsBytes(bytes.buffer.asUint8List());
      }

      final waveFile = File(p.join(tmp.path, '$filename.wave'));

      Waveform? waveform;
      await JustWaveform.extract(
        audioInFile: audioFile,
        waveOutFile: waveFile,
        zoom: const WaveformZoom.pixelsPerSecond(100),
      ).forEach((progress) {
        if (progress.waveform != null) waveform = progress.waveform;
      });

      if (waveform == null) return null;

      final bars = _downsample(waveform!, barCount);
      _cache[cacheKey] = bars;
      return bars;
    } catch (e) {
      debugPrint('WaveformService.extract() error: $e');
      return null;
    }
  }

  static List<double> _downsample(Waveform waveform, int barCount) {
    final length = waveform.length;
    if (length == 0) return List.filled(barCount, 0.5);

    double maxAmp = 0;

    final raw = List.generate(barCount, (i) {
      final start = ((i / barCount) * length).floor();
      final end = (((i + 1) / barCount) * length).floor().clamp(
        start + 1,
        length,
      );

      double peak = 0;
      for (int j = start; j < end; j++) {
        final lo = waveform.getPixelMin(j).abs().toDouble();
        final hi = waveform.getPixelMax(j).abs().toDouble();
        final v = math.max(lo, hi);
        if (v > peak) peak = v;
      }
      if (peak > maxAmp) maxAmp = peak;
      return peak;
    });

    if (maxAmp == 0) return List.filled(barCount, 0.5);

    return raw.map((v) => math.max(0.05, v / maxAmp)).toList();
  }
}
