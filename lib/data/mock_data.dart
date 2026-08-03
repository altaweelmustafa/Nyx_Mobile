class MockTrack {
  final String id;
  final String title;
  final String artist;
  final String song;
  final String audioUrl;
  final String?
  thumbnailPath; // local asset path e.g. 'assets/images/on_my_way.jpg'
  final String?
  lyricsPath; // local asset path e.g. 'assets/lyrics/on_my_way.lrc'
  bool liked;

  MockTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.song,
    required this.audioUrl,
    this.thumbnailPath,
    this.lyricsPath,
    this.liked = false,
  });
}

class MockPlaylist {
  final String id;
  final String name;
  final int trackCount;
  final int likes;
  final List<MockTrack> tracks;

  MockPlaylist({
    required this.id,
    required this.name,
    required this.trackCount,
    required this.likes,
    required this.tracks,
  });
}

// ── Tracks ────────────────────────────────────────────────────────────────────

final mockTracks = [
  MockTrack(
    id: '1',
    title: 'Summertime Sadness',
    artist: 'Lana Del Rey',
    song: 'SONG',
    audioUrl: 'asset:///assets/audio/summertime_sadness.mp3',
    thumbnailPath: 'assets/images/summertime_sadness.jpg',
    lyricsPath: 'assets/lyrics/summertime_sadness.lrc',
    liked: true,
  ),
  MockTrack(
    id: '4',
    title: 'On My Way',
    artist: 'Alan Walker & Sabrina Carpenter',
    song: 'SONG',
    audioUrl: 'asset:///assets/audio/on_my_way.mp3',
    thumbnailPath: 'assets/images/on_my_way.jpg',
    lyricsPath: 'assets/lyrics/on_my_way.lrc',
    liked: true,
  ),
  MockTrack(
    id: '5',
    title: 'NRJ Egypt',
    artist: 'Egypt',
    song: 'RADIO',
    audioUrl: 'https://nrjstreaming.ahmed-melege.com/nrjegypt',
    liked: false,
  ),
  MockTrack(
    id: '6',
    title: 'Faded',
    artist: 'Alan Walker',
    song: 'SONG',
    audioUrl: 'asset:///assets/audio/faded.mp3',
    thumbnailPath: 'assets/images/faded.jpg',
    lyricsPath: 'assets/lyrics/faded.lrc',
    liked: false,
  ),
  MockTrack(
    id: '7',
    title: 'Genesis',
    artist: 'Grimes',
    song: 'SONG',
    audioUrl: 'asset:///assets/audio/grimes_genesis.m4a',
    thumbnailPath: 'assets/images/grimes_genesis.jpg',
    lyricsPath: 'assets/lyrics/grimes_genesis.lrc',
    liked: false,
  ),
  MockTrack(
    id: '8',
    title: 'Delicate Weapon',
    artist: 'Grimes & Lizzy Wizzy',
    song: 'SONG',
    audioUrl: 'asset:///assets/audio/grimes_lizzy_wizzy_delicate_weapon.m4a',
    thumbnailPath: 'assets/images/grimes_lizzy_wizzy_delicate_weapon.jpg',
    lyricsPath: 'assets/lyrics/grimes_lizzy_wizzy_delicate_weapon.lrc',
    liked: false,
  ),
  MockTrack(
    id: '9',
    title: 'Espresso',
    artist: 'Sabrina Carpenter',
    song: 'SONG',
    audioUrl: 'asset:///assets/audio/sabrina_carpenter_espresso.m4a',
    thumbnailPath: 'assets/images/sabrina_carpenter_espresso.jpg',
    lyricsPath: 'assets/lyrics/sabrina_carpenter_espresso.lrc',
    liked: false,
  ),
];

// ── Playlists ─────────────────────────────────────────────────────────────────

// Look up by id rather than list position -- positions shift whenever a
// track is added/removed above, which is what caused the last RangeError.
MockTrack _track(String id) => mockTracks.firstWhere((t) => t.id == id);

final mockPlaylists = [
  MockPlaylist(
    id: 'p1',
    name: 'Playlist #1',
    trackCount: 13,
    likes: 7,
    tracks: [_track('1'), _track('4'), _track('6')],
  ),
  MockPlaylist(
    id: 'p2',
    name: 'Playlist #2',
    trackCount: 5,
    likes: 4,
    tracks: [_track('4')],
  ),
  MockPlaylist(
    id: 'p3',
    name: 'Study',
    trackCount: 9,
    likes: 5,
    tracks: [_track('1'), _track('4'), _track('6'), _track('7'), _track('8'), _track('9')],
  ),
];

// ── Search history ────────────────────────────────────────────────────────────

final mockSearchHistory = [
  'Lana Del Rey',
  '505',
  'Do you love me back',
  'لما قلبي يدق بغار عليك',
];


class LyricLine {
  final String text;
  final bool isActive;
  LyricLine({required this.text, required this.isActive});
}
