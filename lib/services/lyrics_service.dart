import 'package:flutter/services.dart';

class LrcLine {
  final Duration timestamp;
  final String text;

  const LrcLine({required this.timestamp, required this.text});
}

class LyricsService {
  static Future<List<LrcLine>> load(String? assetPath) async {
    if (assetPath == null) return [];
    try {
      final raw = await rootBundle.loadString(assetPath);
      return _parse(raw);
    } catch (e) {
      return [];
    }
  }

  static int activeIndex(List<LrcLine> lines, Duration position) {
    if (lines.isEmpty) return -1;
    int active = -1;
    for (int i = 0; i < lines.length; i++) {
      if (position >= lines[i].timestamp) {
        active = i;
      } else {
        break;
      }
    }
    return active;
  }

  static List<LrcLine> _parse(String raw) {
    final lines = <LrcLine>[];
    final re = RegExp(r'\[(\d+):(\d+)\.(\d+)\](.*)');

    for (final raw_line in raw.split('\n')) {
      final match = re.firstMatch(raw_line.trim());
      if (match == null) continue;

      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      final centStr = match.group(3)!;
      final ms = centStr.length == 2
          ? int.parse(centStr) * 10
          : int.parse(centStr);
      final text = match.group(4)!.trim();

      if (text.isEmpty) continue;

      lines.add(
        LrcLine(
          timestamp: Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: ms,
          ),
          text: text,
        ),
      );
    }

    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }
}
