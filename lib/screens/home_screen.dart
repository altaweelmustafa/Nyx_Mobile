import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';
import '../services/audio_player_service.dart';
import '../widgets/thumbnail.dart';
import '../widgets/track_thumbnail.dart';
import 'track_view_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Real songs vs. live radio streams -- kept separate since radio gets its
  // own row and plays as a single station, not a skippable queue.
  List<MockTrack> get _forYouTracks =>
      mockTracks.where((t) => t.song != 'RADIO').toList();
  List<MockTrack> get _radioStations =>
      mockTracks.where((t) => t.song == 'RADIO').toList();

  void _play(BuildContext context, List<MockTrack> queue, int index) {
    context.read<AudioPlayerService>().playQueue(queue, index);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TrackViewScreen(track: queue[index])),
    );
  }

  void _playStation(BuildContext context, MockTrack station) {
    context.read<AudioPlayerService>().play(station);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TrackViewScreen(track: station)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final forYou = _forYouTracks;
    final radio = _radioStations;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 160),
          children: [
            const SizedBox(height: 24),

            // ── For You ──────────────────────────────────────────────────────
            _SectionHeader(title: 'For You'),
            const SizedBox(height: 16),
            _TrackCardRow(
              tracks: forYou,
              onTap: (i) => _play(context, forYou, i),
            ),

            const SizedBox(height: 32),

            // ── Radio Stations ──────────────────────────────────────────────
            _SectionHeader(title: 'Radio Stations'),
            const SizedBox(height: 16),
            _RadioStationRow(
              stations: radio,
              onTap: (station) => _playStation(context, station),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    );
  }
}

// ── For You: real, playable tracks ───────────────────────────────────────────

class _TrackCardRow extends StatelessWidget {
  final List<MockTrack> tracks;
  final void Function(int index) onTap;

  const _TrackCardRow({required this.tracks, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 188,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: tracks.length,
        itemBuilder: (context, i) {
          final track = tracks[i];
          return Padding(
            padding: EdgeInsets.only(right: i < tracks.length - 1 ? 12 : 0),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: SizedBox(
                width: 130,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TrackThumbnail(
                      size: 130,
                      assetPath: track.thumbnailPath,
                      borderRadius: 10,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.sans,
                        fontFamilyFallback: AppFonts.fallback,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.sans,
                        fontFamilyFallback: AppFonts.fallback,
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Radio Stations: live streams, playable now -- more get added later ──────

class _RadioStationRow extends StatelessWidget {
  final List<MockTrack> stations;
  final void Function(MockTrack station) onTap;

  const _RadioStationRow({required this.stations, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (stations.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 168,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: stations.length,
        itemBuilder: (context, i) {
          final station = stations[i];
          return Padding(
            padding: EdgeInsets.only(right: i < stations.length - 1 ? 12 : 0),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(station),
              child: SizedBox(
                width: 120,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Thumbnail(
                      size: 120,
                      borderRadius: 10,
                      child: const Center(
                        child: Icon(
                          Icons.radio,
                          color: AppColors.background,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      station.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.sans,
                        fontFamilyFallback: AppFonts.fallback,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      station.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.mono,
                        fontFamilyFallback: AppFonts.fallback,
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
