import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';
import '../widgets/thumbnail.dart';
import '../widgets/waveform_scrubber.dart';
import 'lyrics_screen.dart';

class TrackViewScreen extends StatefulWidget {
  final MockTrack track;

  const TrackViewScreen({super.key, required this.track});

  @override
  State<TrackViewScreen> createState() => _TrackViewScreenState();
}

class _TrackViewScreenState extends State<TrackViewScreen> {
  bool _isPlaying = true;
  bool _isShuffle = false;
  bool _isRepeat = false;
  double _progress = 0.42;
  late bool _liked;

  @override
  void initState() {
    super.initState();
    _liked = widget.track.liked;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ────────────────────────────────────────────────────
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
                      widget.track.title,
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

            // ── Album art ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: AspectRatio(
                aspectRatio: 1,
                child: Thumbnail(
                  size: double.infinity,
                  borderRadius: 12,
                  child: const Center(
                    child: Text(
                      'COVER',
                      style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── Track info + like ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.track.title,
                          style: const TextStyle(
                            fontFamily: AppFonts.sans,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.track.artist,
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

            // ── Progress bar ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: WaveformScrubber(
                progress: _progress,
                height: 48,
                passiveColor: const Color(0xFF555555),
                onChanged: (v) => setState(() => _progress = v),
              ),
            ),

            const SizedBox(height: 6),

            // ── Time stamps ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '1:32',
                    style: const TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '3:38',
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

            // ── Transport controls ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _isShuffle = !_isShuffle),
                    child: Icon(
                      Icons.shuffle,
                      color: _isShuffle
                          ? AppColors.accent
                          : AppColors.textPrimary,
                      size: 24,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: const Icon(
                      Icons.skip_previous,
                      color: AppColors.textPrimary,
                      size: 36,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _isPlaying = !_isPlaying),
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        color: AppColors.textPrimary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: AppColors.background,
                        size: 32,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: const Icon(
                      Icons.skip_next,
                      color: AppColors.textPrimary,
                      size: 36,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _isRepeat = !_isRepeat),
                    child: Icon(
                      Icons.repeat,
                      color: _isRepeat
                          ? AppColors.accent
                          : AppColors.textPrimary,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Bluetooth device ───────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.bluetooth, size: 14, color: AppColors.accent),
                SizedBox(width: 6),
                Text(
                  "Bluetooth's Device Name",
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 12,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Bottom actions ─────────────────────────────────────────────
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

// ── Action button ──────────────────────────────────────────────────────────────

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
