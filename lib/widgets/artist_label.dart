import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../screens/artist_screen.dart';
import '../utils/artist_names.dart';

/// Renders a track's artist credit -- possibly composite, e.g. "Grimes &
/// Lizzy Wizzy" -- as text where each individual artist name is tappable
/// and opens that artist's ArtistScreen. Drop-in replacement for a plain
/// `Text(track.artist, style: ...)`.
class ArtistLabel extends StatefulWidget {
  final String artist;
  final TextStyle style;
  final String? thumbnailPath;
  final int maxLines;
  final TextOverflow overflow;
  final TextAlign textAlign;

  const ArtistLabel({
    super.key,
    required this.artist,
    required this.style,
    this.thumbnailPath,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.textAlign = TextAlign.start,
  });

  @override
  State<ArtistLabel> createState() => _ArtistLabelState();
}

class _ArtistLabelState extends State<ArtistLabel> {
  final List<TapGestureRecognizer> _recognizers = [];

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _openArtist(String name) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ArtistScreen(artist: name, thumbnailPath: widget.thumbnailPath),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilt fresh every build -- cheap, and keeps each recognizer's
    // closure bound to the artist name it was created for.
    _disposeRecognizers();

    final names = splitArtists(widget.artist);
    final List<InlineSpan> spans;
    if (names.length <= 1) {
      final recognizer = TapGestureRecognizer()
        ..onTap = () => _openArtist(widget.artist);
      _recognizers.add(recognizer);
      spans = [
        TextSpan(text: widget.artist, style: widget.style, recognizer: recognizer),
      ];
    } else {
      spans = [];
      for (var i = 0; i < names.length; i++) {
        if (i > 0) spans.add(TextSpan(text: ', ', style: widget.style));
        final recognizer = TapGestureRecognizer()
          ..onTap = () => _openArtist(names[i]);
        _recognizers.add(recognizer);
        spans.add(
          TextSpan(text: names[i], style: widget.style, recognizer: recognizer),
        );
      }
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      textAlign: widget.textAlign,
    );
  }
}
