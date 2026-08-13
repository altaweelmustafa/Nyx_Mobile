import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/track.dart';
import '../repositories/artist_repository.dart';
import '../repositories/playlist_repository.dart';
import '../repositories/track_repository.dart';
import '../services/audio_player_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/collection_header.dart';
import '../widgets/song_actions.dart';
import '../widgets/track_row_tap.dart';
import '../widgets/track_thumbnail.dart';

/// All of an artist's tracks, shown as rows -- effectively an
/// auto-generated playlist for that artist. Tapping any row plays the
/// whole list as the queue, starting from that track.
class ArtistScreen extends StatefulWidget {
  final String artist;
  final String? thumbnailPath;

  const ArtistScreen({super.key, required this.artist, this.thumbnailPath});

  @override
  State<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends State<ArtistScreen> {
  final _trackRepo = TrackRepository();
  final _artistRepo = ArtistRepository();
  final _playlistRepo = PlaylistRepository();
  List<Track> _tracks = [];
  ArtistProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tracks = await _trackRepo.getByArtist(widget.artist);
    final profile = await _artistRepo.getByName(widget.artist);
    if (!mounted) return;
    setState(() {
      _tracks = tracks;
      _profile = profile;
      _loading = false;
    });
  }

  void _showSongOptions(int index) {
    final track = _tracks[index];
    showSongOptionsSheet(
      context,
      track: track,
      trackRepo: _trackRepo,
      playlistRepo: _playlistRepo,
      liked: track.liked,
      onLikeChanged: (liked) {
        if (!mounted) return;
        setState(() => _tracks[index] = track.copyWith(liked: liked));
      },
      removeLabel: 'Remove from Library',
      onRemove: () async {
        await _trackRepo.deleteTrack(track.id);
        if (!mounted) return;
        setState(() => _tracks.removeAt(index));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTrackId = context.watch<AudioPlayerService>().currentTrack?.id;
    // Real synced photo first, then whatever the caller had on hand (e.g. a
    // track thumbnail from Home), then this artist's own first track --
    // covers artists orc hasn't backfilled a photo for yet.
    final thumbnail = _profile?.photoPath ??
        widget.thumbnailPath ??
        (_tracks.isNotEmpty ? _tracks.first.thumbnailPath : null);
    final bio = _profile?.bio;

    return AppScaffold(
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── App bar ────────────────────────────────────────────────
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
                      ],
                    ),
                  ),

                  // ── Artist header ─────────────────────────────────────────
                  CollectionHeader(
                    title: widget.artist,
                    subtitle: '${_tracks.length} TRACKS',
                    thumbnailPath: thumbnail,
                    thumbnailBorderRadius: 36, // circular -- artists always are
                    onPlayAll: _tracks.isEmpty
                        ? null
                        : () => handleTrackTap(context, _tracks, 0),
                  ),

                  // ── Bio ───────────────────────────────────────────────────
                  if (bio != null && bio.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Text(
                        bio,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppFonts.sans,
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),

                  // ── Track list ────────────────────────────────────────────
                  Expanded(
                    child: _tracks.isEmpty
                        ? const Center(
                            child: Text(
                              'No tracks',
                              style: TextStyle(
                                fontFamily: AppFonts.sans,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _tracks.length,
                            itemBuilder: (context, i) {
                              final track = _tracks[i];
                              final isNowPlaying = track.id == currentTrackId;
                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => handleTrackTap(context, _tracks, i),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                    children: [
                                      TrackThumbnail(
                                        size: 46,
                                        assetPath: track.thumbnailPath,
                                        borderRadius: 6,
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              track.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontFamily: AppFonts.sans,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                                color: isNowPlaying
                                                    ? AppColors.accent
                                                    : AppColors.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => _showSongOptions(i),
                                        child: const Icon(
                                          Icons.more_vert,
                                          color: AppColors.textSecondary,
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
