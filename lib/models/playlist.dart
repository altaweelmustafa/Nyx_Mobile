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

  /// Non-null once this playlist is mirrored on the homelab server -- the
  /// id under which every device that syncs knows it. That's what "public"
  /// means here: any device can pull it, add/remove tracks, or add it to
  /// its own Library. Null means either not-yet-uploaded, or a locked
  /// artist-snapshot playlist, which never syncs.
  final String? serverId;

  const Playlist({
    required this.id,
    required this.name,
    required this.likes,
    required this.trackCount,
    this.liked = false,
    this.sourceArtist,
    this.serverId,
  });

  bool get isLocked => sourceArtist != null;
  bool get isShared => serverId != null;

  factory Playlist.fromMap(Map<String, Object?> map) => Playlist(
    id: map['id'].toString(),
    name: map['name'] as String,
    likes: map['likes'] as int,
    trackCount: (map['track_count'] as int?) ?? 0,
    liked: (map['liked'] as int) != 0,
    sourceArtist: map['source_artist'] as String?,
    serverId: map['server_id'] as String?,
  );

  Playlist copyWith({bool? liked}) => Playlist(
    id: id,
    name: name,
    likes: likes,
    trackCount: trackCount,
    liked: liked ?? this.liked,
    sourceArtist: sourceArtist,
    serverId: serverId,
  );
}
