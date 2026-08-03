import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';
import '../services/audio_player_service.dart';
import '../widgets/bluetooth_indicator.dart';
import '../widgets/loop_mode_button.dart';
import '../services/waveform_service.dart';
import '../widgets/track_thumbnail.dart';
import '../widgets/waveform_scrubber.dart';
import 'lyrics_screen.dart';

class TrackViewScreen extends StatefulWidget {
  final MockTrack track;

  const TrackViewScreen({super.key, required this.track});

  @override
  State<TrackViewScreen> createState() => _TrackViewScreenState();
}

class _TrackViewScreenState extends State<TrackViewScreen> {
  late bool _liked;
  double? _dragProgress;
  List<double>? _waveformBars;
  String? _loadedTrackId;
  AudioPlayerService? _svc;

  @override
  void initState() {
    super.initState();
    _liked = widget.track.liked;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AudioPlayerService>().play(widget.track);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _svc?.removeListener(_onTrackChanged);
    _svc = context.read<AudioPlayerService>();
    _svc!.addListener(_onTrackChanged);
    _maybeReloadWaveform(_svc!.currentTrack ?? widget.track);
  }

  void _onTrackChanged() {
    final track = _svc?.currentTrack;
    if (track != null && track.id != _loadedTrackId) {
      setState(() {
        _liked = track.liked;
        _waveformBars = null;
      });
      _maybeReloadWaveform(track);
    }
  }

  void _maybeReloadWaveform(MockTrack track) {
    if (track.id == _loadedTrackId) return;
    _loadedTrackId = track.id;
    _loadWaveform(track);
  }

  Future<void> _loadWaveform(MockTrack track) async {
    final url = track.audioUrl;
    final assetPath = url.startsWith('asset:///assets/')
        ? url.replaceFirst('asset:///', '')
        : null;
    final bars = await WaveformService.extract(assetPath);
    if (mounted) setState(() => _waveformBars = bars);
  }

  @override
  void dispose() {
    _svc?.removeListener(_onTrackChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<AudioPlayerService>();
    final track = svc.currentTrack ?? widget.track;
    final progress = _dragProgress ?? svc.progress;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textPrimary,
                      size: 24,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      track.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: AppFonts.sans,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.more_vert,
                      color: AppColors.textPrimary,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Album art ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: AspectRatio(
                aspectRatio: 1,
                child: TrackThumbnail(
                  size: double.infinity,
                  assetPath: track.thumbnailPath,
                  borderRadius: 12,
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── Track info + like ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          style: const TextStyle(
                            fontFamily: AppFonts.sans,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          track.artist,
                          style: const TextStyle(
                            fontFamily: AppFonts.sans,
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _liked = !_liked),
                    child: Icon(
                      _liked ? Icons.favorite : Icons.favorite_border,
                      color: _liked
                          ? AppColors.accent
                          : AppColors.textSecondary,
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Waveform scrubber ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: svc.isLoading
                  ? const SizedBox(
                      height: 48,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: AppColors.accent,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    )
                  : WaveformScrubber(
                      progress: progress,
                      height: 48,
                      bars: _waveformBars,
                      passiveColor: const Color(0xFF555555),
                      onChanged: (v) => setState(() => _dragProgress = v),
                      onChangeEnd: (v) {
                        setState(() => _dragProgress = null);
                        svc.seekToFraction(v);
                      },
                    ),
            ),

            const SizedBox(height: 6),

            // ── Timestamps ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    svc.positionLabel,
                    style: const TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    svc.durationLabel,
                    style: const TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Transport controls ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: svc.toggleShuffle,
                    child: Icon(
                      Icons.shuffle,
                      color: svc.isShuffle
                          ? AppColors.accent
                          : AppColors.textPrimary,
                      size: 24,
                    ),
                  ),
                  GestureDetector(
                    onTap: svc.playPrevious,
                    child: const Icon(
                      Icons.skip_previous,
                      color: AppColors.textPrimary,
                      size: 36,
                    ),
                  ),
                  GestureDetector(
                    onTap: svc.togglePlayPause,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        color: AppColors.textPrimary,
                        shape: BoxShape.circle,
                      ),
                      child: svc.isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(
                                color: AppColors.background,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Icon(
                              svc.isPlaying ? Icons.pause : Icons.play_arrow,
                              color: AppColors.background,
                              size: 32,
                            ),
                    ),
                  ),
                  GestureDetector(
                    onTap: svc.playNext,
                    child: const Icon(
                      Icons.skip_next,
                      color: AppColors.textPrimary,
                      size: 36,
                    ),
                  ),
                  LoopModeButton(loopMode: svc.loopMode, onTap: svc.toggleRepeat, size: 24),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Bluetooth ────────────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 28),
              child: Align(
                alignment: Alignment.centerLeft,
                child: BluetoothIndicator(
                  iconSize: 14,
                  fontSize: 12,
                  nameWidth: 200,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Bottom actions ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ActionButton(
                    icon: Icons.queue_music,
                    label: 'Queue',
                    onTap: () {},
                  ),
                  _ActionButton(
                    icon: Icons.lyrics_outlined,
                    label: 'Lyrics',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LyricsScreen(track: widget.track),
                      ),
                    ),
                  ),
                  _ActionButton(
                    icon: Icons.share_outlined,
                    label: 'Share',
                    onTap: () {},
                  ),
                  _ActionButton(
                    icon: Icons.more_horiz,
                    label: 'More',
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: AppColors.textPrimary, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
