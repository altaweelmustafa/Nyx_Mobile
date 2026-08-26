class Playlist {
  final String id;
  final String name;
  final int likes;
  final int trackCount;
  final bool liked;

  /// The artist name this playlist was saved from via "Save as Playlist"
  /// on an artist page, or null for a regular user-created playlist. A
  /// non-null value marks the playlist locked: its name and track list
  /// can't be edited, only deleted.
  final String? sourceArtist;

  const Playlist({
    required this.id,
    required this.name,
    required this.likes,
    required this.trackCount,
    this.liked = false,
    this.sourceArtist,
  });

  bool get isLocked => sourceArtist != null;

  factory Playlist.fromMap(Map<String, Object?> map) => Playlist(
    id: map['id'].toString(),
    name: map['name'] as String,
    likes: map['likes'] as int,
    trackCount: (map['track_count'] as int?) ?? 0,
    liked: (map['liked'] as int) != 0,
    sourceArtist: map['source_artist'] as String?,
  );

  Playlist copyWith({bool? liked}) => Playlist(
    id: id,
    name: name,
    likes: likes,
    trackCount: trackCount,
    liked: liked ?? this.liked,
    sourceArtist: sourceArtist,
  );
}
