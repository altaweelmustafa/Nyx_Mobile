import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../config.dart';
import '../theme/app_theme.dart';
import '../models/track.dart';
import '../repositories/playlist_repository.dart';
import '../repositories/track_repository.dart';
import '../services/artwork_color_service.dart';
import '../services/audio_player_service.dart';
import '../services/jam_service.dart';
import '../widgets/bluetooth_indicator.dart';
import '../widgets/loop_mode_button.dart';
import '../services/waveform_service.dart';
import '../widgets/nyx_toast.dart';
import '../widgets/options_sheet.dart';
import '../widgets/song_actions.dart';
import '../widgets/track_thumbnail.dart';
import '../widgets/waveform_scrubber.dart';
import 'lyrics_screen.dart';

/// Album art fills the available width via AspectRatio, so the generic
/// [kDesktopContentMaxWidth] (1040, meant for list-shaped screens) would
/// blow the art up to ~960px square. Cap this screen at a narrower,
/// player-card-shaped width instead, the way a desktop "now playing" view
/// (Spotify, Apple Music) stays narrow even in a wide window.
const _kPlayerMaxWidth = 420.0;

class TrackViewScreen extends StatefulWidget {
  final Track track;

  const TrackViewScreen({super.key, required this.track});

  @override
  State<TrackViewScreen> createState() => _TrackViewScreenState();
}

class _TrackViewScreenState extends State<TrackViewScreen> {
  final _trackRepo = TrackRepository();
  final _playlistRepo = PlaylistRepository();
  late bool _liked;
  double? _dragProgress;
  List<double>? _waveformBars;
  String? _loadedTrackId;
  AudioPlayerService? _svc;
  Color? _bgColor;

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

  void _maybeReloadWaveform(Track track) {
    if (track.id == _loadedTrackId) return;
    _loadedTrackId = track.id;
    _loadWaveform(track);
    _loadBackgroundColor(track);
  }

  Future<void> _loadWaveform(Track track) async {
    final bars = await WaveformService.extract(track.audioUrl);
    if (mounted) setState(() => _waveformBars = bars);
  }

  Future<void> _loadBackgroundColor(Track track) async {
    final color = await ArtworkColorService.extract(track.thumbnailPath);
    if (!mounted || track.id != _loadedTrackId) return;
    setState(
      () => _bgColor = color == null
          ? null
          : ArtworkColorService.tuneForBackground(color),
    );
  }

  @override
  void dispose() {
    _svc?.removeListener(_onTrackChanged);
    super.dispose();
  }

  void _share(Track track) {
    final caption = '${track.title} — ${track.artist}';
    // Locally-added tracks (never synced from orc) have no slug, so there's
    // no stable id to build a link from -- share the caption alone rather
    // than a link that would 404 for the recipient.
    final slug = track.slug;
    SharePlus.instance.share(
      ShareParams(
        text: slug == null ? caption : '$caption\n$kDefaultServerUrl/t/$slug',
      ),
    );
  }

  Future<void> _addToPlaylist(Track track) =>
      addTrackToPlaylist(context, track, _playlistRepo);

  void _showTrackOptions(Track track) {
    showOptionsSheet(
      context,
      title: track.title,
      options: [
        SheetOption(
          icon: Icons.playlist_add,
          label: 'Add to Playlist',
          onTap: () => _addToPlaylist(track),
        ),
        SheetOption(
          icon: Icons.share_outlined,
          label: 'Share',
          onTap: () => _share(track),
        ),
        SheetOption(
          icon: Icons.delete_outline,
          label: 'Remove from Library',
          destructive: true,
          onTap: () => _removeFromLibrary(track),
        ),
      ],
    );
  }

  Future<void> _removeFromLibrary(Track track) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Remove from Library?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          '"${track.title}" will be permanently deleted.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _trackRepo.deleteTrack(track.id);
    if (!mounted) return;
    NyxToast.show(context, 'Removed from Library', icon: Icons.delete_outline);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<AudioPlayerService>();
    final track = svc.currentTrack ?? widget.track;
    final progress = _dragProgress ?? svc.progress;
    final following = context.watch<JamService>().role == JamRole.client;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgColor ?? AppColors.background, AppColors.background],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: context.isDesktop ? _kPlayerMaxWidth : double.infinity,
            ),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
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
                                  onPressed: () => _showTrackOptions(track),
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
                              child: Hero(
                                tag: 'track-art-${track.id}',
                                child: TrackThumbnail(
                                  size: double.infinity,
                                  assetPath: track.thumbnailPath,
                                  borderRadius: 12,
                                ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                  onTap: () {
                                    final liked = !_liked;
                                    setState(() => _liked = liked);
                                    _trackRepo.setLiked(track.id, liked);
                                    NyxToast.show(
                                      context,
                                      liked
                                          ? 'Added to Liked Songs'
                                          : 'Removed from Liked Songs',
                                      icon: liked
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                    );
                                  },
                                  child: Icon(
                                    _liked
                                        ? Icons.favorite
                                        : Icons.favorite_border,
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
                                    onChanged: following
                                        ? null
                                        : (v) =>
                                              setState(() => _dragProgress = v),
                                    onChangeEnd: following
                                        ? null
                                        : (v) {
                                            setState(
                                              () => _dragProgress = null,
                                            );
                                            svc.seekToFraction(v);
                                          },
                                  ),
                          ),

                          if (following) ...[
                            const SizedBox(height: 6),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 28),
                              child: Text(
                                'Host is in control during a Roll',
                                style: TextStyle(
                                  fontFamily: AppFonts.sans,
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],

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
                            child: Opacity(
                              opacity: following ? 0.4 : 1.0,
                              child: IgnorePointer(
                                ignoring: following,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
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
                                                child:
                                                    CircularProgressIndicator(
                                                      color:
                                                          AppColors.background,
                                                      strokeWidth: 2.5,
                                                    ),
                                              )
                                            : AnimatedSwitcher(
                                                duration: const Duration(
                                                  milliseconds: 200,
                                                ),
                                                transitionBuilder: (child, anim) =>
                                                    ScaleTransition(
                                                      scale: anim,
                                                      child: child,
                                                    ),
                                                child: Icon(
                                                  svc.isPlaying
                                                      ? Icons.pause
                                                      : Icons.play_arrow,
                                                  key: ValueKey(svc.isPlaying),
                                                  color: AppColors.background,
                                                  size: 32,
                                                ),
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
                                    LoopModeButton(
                                      loopMode: svc.loopMode,
                                      onTap: svc.toggleRepeat,
                                      size: 24,
                                    ),
                                  ],
                                ),
                              ),
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
                                  icon: Icons.playlist_add,
                                  label: 'Playlist',
                                  onTap: () => _addToPlaylist(track),
                                ),
                                _ActionButton(
                                  icon: Icons.lyrics_outlined,
                                  label: 'Lyrics',
                                  // `track` (svc.currentTrack ?? widget.track),
                                  // not widget.track -- this screen stays open
                                  // across playback advancing to the next
                                  // track, so widget.track can be stale.
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          LyricsScreen(track: track),
                                    ),
                                  ),
                                ),
                                _ActionButton(
                                  icon: Icons.share_outlined,
                                  label: 'Share',
                                  onTap: () => _share(track),
                                ),
                                _ActionButton(
                                  icon: Icons.more_horiz,
                                  label: 'More',
                                  onTap: () => _showTrackOptions(track),
                                ),
                              ],
                            ),
                          ),

                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
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
