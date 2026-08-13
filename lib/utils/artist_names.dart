/// Splits a composite credit string into individual artist names, e.g.
/// "Grimes & Lizzy Wizzy" -> ["Grimes", "Lizzy Wizzy"]. A name with no
/// separator comes back as a single-element list.
///
/// Keep this in sync with orc's `split_artists()` in `~/git/orc/artists.py`
/// -- the two must agree on what counts as an individual artist, or synced
/// photo/bio entries silently stop lining up with the `track_artists` rows
/// built from this function.
///
/// Known accepted gap: ampersand-named duos that are actually one act (e.g.
/// "Simon & Garfunkel") will incorrectly split -- not solved here.
final _splitPattern = RegExp(
  r'\s*(?:&|,|/| feat\.?\s| ft\.?\s| featuring | x | vs\.?\s)\s*',
  caseSensitive: false,
);

List<String> splitArtists(String raw) {
  return raw
      .split(_splitPattern)
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
}
