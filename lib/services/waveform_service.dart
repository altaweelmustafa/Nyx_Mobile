import 'dart:io';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_waveform/just_waveform.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class WaveformService {
  WaveformService._();

  static final _dio = Dio();
  static final _cache = <String, List<double>>{};

  /// Extracts real per-bar amplitude data from the actual audio -- decodes
  /// [audioUrl] (a bundled 'assets/...' path, a legacy 'asset:///assets/...'
  /// URI, or a full http(s) URL to server-hosted audio) rather than ever
  /// faking it. Remote audio is downloaded once to the temp dir and reused
  /// on later calls, same as bundled assets always were.
  static Future<List<double>?> extract(
    String? audioUrl, {
    int barCount = 200,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS) {
      // just_waveform has no Linux/Windows decoder -- those platforms keep
      // the animated fallback in WaveformScrubber, same as before.
      return null;
    }

    if (audioUrl == null) return null;

    final cacheKey = '$audioUrl:$barCount';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    try {
      final audioFile = await _localAudioFile(audioUrl);
      if (audioFile == null) return null;

      final tmp = await getTemporaryDirectory();
      final waveFile = File(p.join(tmp.path, '${p.basename(audioFile.path)}.wave'));

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

  /// Resolves [audioUrl] to a local file just_waveform can decode.
  /// Bundled-asset bytes come from rootBundle; remote audio is downloaded
  /// via dio to a `.part` file first and renamed only once the download
  /// completes, so a killed/interrupted download can't leave behind a
  /// truncated file that looks cached on the next attempt.
  static Future<File?> _localAudioFile(String audioUrl) async {
    final tmp = await getTemporaryDirectory();

    if (audioUrl.startsWith('http://') || audioUrl.startsWith('https://')) {
      final segments = Uri.parse(audioUrl).pathSegments;
      final filename = segments.isNotEmpty ? segments.last : audioUrl.hashCode.toString();
      final audioFile = File(p.join(tmp.path, filename));
      if (!audioFile.existsSync()) {
        final partFile = File('${audioFile.path}.part');
        await _dio.download(audioUrl, partFile.path);
        await partFile.rename(audioFile.path);
      }
      return audioFile;
    }

    final assetPath = audioUrl.startsWith('asset:///')
        ? audioUrl.replaceFirst('asset:///', '')
        : audioUrl;
    if (assetPath.startsWith('assets/')) {
      final filename = p.basename(assetPath);
      final audioFile = File(p.join(tmp.path, filename));
      if (!audioFile.existsSync()) {
        final bytes = await rootBundle.load(assetPath);
        await audioFile.writeAsBytes(bytes.buffer.asUint8List());
      }
      return audioFile;
    }

    return null;
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
