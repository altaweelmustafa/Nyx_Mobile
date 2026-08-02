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
    id: '2',
    title: 'Say Yes To Heaven',
    artist: 'Lana Del Rey',
    song: 'SONG',
    audioUrl:
        'https://cdns-preview-e.dzcdn.net/stream/c-e77d23e0c8c56974edce9d0a8c6b1fb0-3.mp3',
    liked: false,
  ),
  MockTrack(
    id: '3',
    title: 'Born To Die',
    artist: 'Lana Del Rey',
    song: 'SONG',
    audioUrl:
        'https://cdns-preview-d.dzcdn.net/stream/c-d975e8b60743e2ce5bbeaef5e78bb0dd-8.mp3',
    liked: false,
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
    title: 'Rotana FM',
    artist: '90.1 FM - EGYPT',
    song: 'RADIO',
    audioUrl: 'https://n05.rcs.revma.com/ypqhjfkzktzuv',
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
];

// ── Playlists ─────────────────────────────────────────────────────────────────

final mockPlaylists = [
  MockPlaylist(
    id: 'p1',
    name: 'Playlist #1',
    trackCount: 13,
    likes: 7,
    tracks: [mockTracks[0], mockTracks[1], mockTracks[2]],
  ),
  MockPlaylist(
    id: 'p2',
    name: 'Playlist #2',
    trackCount: 5,
    likes: 4,
    tracks: [mockTracks[3]],
  ),
  MockPlaylist(
    id: 'p3',
    name: 'Study',
    trackCount: 9,
    likes: 5,
    tracks: [mockTracks[0], mockTracks[3], mockTracks[5], mockTracks[6], mockTracks[7]],
  ),
];

// ── Search history ────────────────────────────────────────────────────────────

final mockSearchHistory = [
  'Lana Del Rey',
  '505',
  'Do you love me back',
  'لما قلبي يدق بغار عليك',
];

// ── For You cards ─────────────────────────────────────────────────────────────

final mockForYouCards = ['history', 'most played', '2022 hit'];

// ── Suggestion genres ─────────────────────────────────────────────────────────

final mockSuggestions = ['SM5A FM', 'Jazz', 'Spanish'];

// ── Lyrics ────────────────────────────────────────────────────────────────────

final mockLyrics = [
  LyricLine(text: "So then, when I'm finished", isActive: false),
  LyricLine(text: "I'm all 'bout my business and", isActive: false),
  LyricLine(text: "ready to save the world", isActive: false),
  LyricLine(text: "I'm taking my misery, make it my bitch", isActive: false),
  LyricLine(text: "Can't be everyone's favorite girl", isActive: false),
  LyricLine(text: "So take aim and fire away", isActive: true),
  LyricLine(text: "I've never been so wide awake", isActive: false),
  LyricLine(text: "No, nobody but me can keep me safe", isActive: false),
  LyricLine(text: "And I'm on my way", isActive: false),
  LyricLine(text: "The blood moon is on the rise", isActive: false),
  LyricLine(text: "The fire burning in my eyes", isActive: false),
  LyricLine(text: "No, nobody but me can keep me safe", isActive: false),
  LyricLine(text: "And I'm on my way", isActive: false),
];

class LyricLine {
  final String text;
  final bool isActive;
  LyricLine({required this.text, required this.isActive});
}
