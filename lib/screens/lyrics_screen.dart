import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/track.dart';
import '../services/lyrics_service.dart';
import '../services/audio_player_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/track_thumbnail.dart';

class LyricsScreen extends StatefulWidget {
  final Track track;

  const LyricsScreen({super.key, required this.track});

  @override
  State<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends State<LyricsScreen> {
  List<LrcLine> _lines = [];
  int _activeIndex = -1;
  bool _isLoading = true;
  final _scrollController = ScrollController();
  // Key list for scrolling to the active line
  final List<GlobalKey> _keys = [];
  bool _userScrolling = false;

  @override
  void initState() {
    super.initState();
    _loadLyrics();
  }

  Future<void> _loadLyrics() async {
    final lines = await LyricsService.load(widget.track.lyricsPath);
    if (!mounted) return;
    setState(() {
      _lines = lines;
      _isLoading = false;
      _keys.clear();
      _keys.addAll(List.generate(lines.length, (_) => GlobalKey()));
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToActive(int index) {
    if (_userScrolling) return;
    if (index < 0 || index >= _keys.length) return;
    final ctx = _keys[index].currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.4, // keep active line at ~40% from top
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<AudioPlayerService>();
    final newActive = LyricsService.activeIndex(_lines, svc.position);

    if (newActive != _activeIndex) {
      _activeIndex = newActive;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToActive(_activeIndex),
      );
    }

    return AppScaffold(
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
                      Icons.arrow_back_ios_new,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Lyrics',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.sans,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Album art ────────────────────────────────────────────────────
            TrackThumbnail(
              size: 80,
              assetPath: widget.track.thumbnailPath,
              borderRadius: 8,
            ),

            const SizedBox(height: 8),

            // ── Track title + artist ─────────────────────────────────────────
            Text(
              widget.track.title,
              style: const TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.track.artist,
              style: const TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 24),

            // ── Lyrics ───────────────────────────────────────────────────────
            Expanded(
              child: _lines.isEmpty
                  ? _emptyState(widget.track.lyricsPath, _isLoading)
                  : NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        // Detect user scrolling to suppress auto-scroll temporarily
                        if (n is ScrollStartNotification &&
                            n.dragDetails != null) {
                          _userScrolling = true;
                        } else if (n is ScrollEndNotification) {
                          Future.delayed(const Duration(seconds: 3), () {
                            if (mounted) _userScrolling = false;
                          });
                        }
                        return false;
                      },
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 20,
                        ),
                        itemCount: _lines.length,
                        itemBuilder: (context, i) {
                          final isActive = i == _activeIndex;
                          return GestureDetector(
                            key: _keys[i],
                            onTap: () {
                              // Tap a line to seek there
                              final ms = _lines[i].timestamp.inMilliseconds;
                              final total = svc.duration.inMilliseconds;
                              if (total > 0) svc.seekToFraction(ms / total);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  fontFamily: AppFonts.sans,
                                  fontSize: isActive ? 18 : 14,
                                  fontWeight: isActive
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: isActive
                                      ? AppColors.accent
                                      : AppColors.textPrimary.withOpacity(0.45),
                                  height: 1.5,
                                ),
                                child: Text(
                                  _lines[i].text,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String? path, bool isLoading) {
    if (path != null && isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    final message = path == null
        ? 'No lyrics available'
        : "Couldn't load synced lyrics for this track";

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.lyrics_outlined,
            color: AppColors.textSecondary,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
