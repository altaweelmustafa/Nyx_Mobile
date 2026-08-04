import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/track.dart';
import '../repositories/track_repository.dart';
import '../services/audio_player_service.dart';
import '../widgets/track_thumbnail.dart';
import 'track_view_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _trackRepo = TrackRepository();
  List<Track> _mostPlayed = [];
  List<Track> _recommended = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _trackRepo.getMostPlayed(3),
      _trackRepo.getRecommended(3),
    ]);
    if (!mounted) return;
    setState(() {
      _mostPlayed = results[0];
      _recommended = results[1];
      _loading = false;
    });
  }

  void _play(BuildContext context, List<Track> queue, int index) {
    context.read<AudioPlayerService>().playQueue(queue, index);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TrackViewScreen(track: queue[index])),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              )
            : ListView(
                padding: const EdgeInsets.only(bottom: 160),
                children: [
                  const SizedBox(height: 24),

                  // ── Most Played ──────────────────────────────────────────────
                  if (_mostPlayed.isNotEmpty) ...[
                    _SectionHeader(title: 'Most Played'),
                    const SizedBox(height: 16),
                    _TrackCardRow(
                      tracks: _mostPlayed,
                      onTap: (i) => _play(context, _mostPlayed, i),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // ── Recommended ──────────────────────────────────────────────
                  if (_recommended.isNotEmpty) ...[
                    _SectionHeader(title: 'Recommended For You'),
                    const SizedBox(height: 16),
                    _TrackCardRow(
                      tracks: _recommended,
                      onTap: (i) => _play(context, _recommended, i),
                    ),
                    const SizedBox(height: 32),
                  ],

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
  final List<Track> tracks;
  final void Function(int index) onTap;

  const _TrackCardRow({required this.tracks, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) return const SizedBox.shrink();
    final currentTrackId = context.watch<AudioPlayerService>().currentTrack?.id;

    return SizedBox(
      height: 188,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: tracks.length,
        itemBuilder: (context, i) {
          final track = tracks[i];
          final isNowPlaying = track.id == currentTrackId;
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
                      style: TextStyle(
                        fontFamily: AppFonts.sans,
                        fontFamilyFallback: AppFonts.fallback,
                        fontSize: 13,
                        color: isNowPlaying ? AppColors.accent : AppColors.textPrimary,
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
