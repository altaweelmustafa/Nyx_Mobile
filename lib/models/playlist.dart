class Playlist {
  final String id;
  final String name;
  final int likes;
  final int trackCount;
  final bool liked;

  const Playlist({
    required this.id,
    required this.name,
    required this.likes,
    required this.trackCount,
    this.liked = false,
  });

  factory Playlist.fromMap(Map<String, Object?> map) => Playlist(
    id: map['id'].toString(),
    name: map['name'] as String,
    likes: map['likes'] as int,
    trackCount: (map['track_count'] as int?) ?? 0,
    liked: (map['liked'] as int) != 0,
  );

  Playlist copyWith({bool? liked}) => Playlist(
    id: id,
    name: name,
    likes: likes,
    trackCount: trackCount,
    liked: liked ?? this.liked,
  );
}
