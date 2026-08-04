class Track {
  final String id;
  final String title;
  final String artist;
  final String song;
  final String audioUrl;
  final String? thumbnailPath; // 'assets/images/x.jpg' (bundled) or a full http(s) URL (server-hosted)
  final String? lyricsPath; // 'assets/lyrics/x.lrc' (bundled) or a full http(s) URL (server-hosted)
  final bool liked;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.song,
    required this.audioUrl,
    this.thumbnailPath,
    this.lyricsPath,
    this.liked = false,
  });

  factory Track.fromMap(Map<String, Object?> map) => Track(
    id: map['id'].toString(),
    title: map['title'] as String,
    artist: map['artist'] as String,
    song: map['song'] as String,
    audioUrl: map['audio_url'] as String,
    thumbnailPath: map['thumbnail_path'] as String?,
    lyricsPath: map['lyrics_path'] as String?,
    liked: (map['liked'] as int) != 0,
  );

  Track copyWith({bool? liked}) => Track(
    id: id,
    title: title,
    artist: artist,
    song: song,
    audioUrl: audioUrl,
    thumbnailPath: thumbnailPath,
    lyricsPath: lyricsPath,
    liked: liked ?? this.liked,
  );
}
