import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';
import '../widgets/thumbnail.dart';
import 'track_view_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode  = FocusNode();
  bool  _isSearching = false;
  String _query = '';

  late List<String> _history;

  @override
  void initState() {
    super.initState();
    _history = List.from(mockSearchHistory);
    _controller.addListener(() {
      setState(() => _query = _controller.text);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startSearch() {
    setState(() => _isSearching = true);
    _focusNode.requestFocus();
  }

  void _cancelSearch() {
    setState(() {
      _isSearching = false;
      _query = '';
    });
    _controller.clear();
    _focusNode.unfocus();
  }

  void _removeHistory(String item) {
    setState(() => _history.remove(item));
  }

  List<MockTrack> get _results {
    if (_query.isEmpty) return [];
    return mockTracks
        .where((t) =>
            t.title.toLowerCase().contains(_query.toLowerCase()) ||
            t.artist.toLowerCase().contains(_query.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // ── Search bar row ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      onTap: _startSearch,
                      style: const TextStyle(
                        fontFamily: AppFonts.sans,
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        labelText: 'SEARCH',
                        labelStyle: const TextStyle(
                          fontFamily: AppFonts.mono,
                          fontSize: 11,
                          letterSpacing: 1.4,
                          color: AppColors.textSecondary,
                        ),
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        floatingLabelAlignment: FloatingLabelAlignment.start,
                        filled: true,
                        fillColor: AppColors.surfaceHigh,
                        contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.accent,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_isSearching) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _cancelSearch,
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontFamily: AppFonts.sans,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Body ────────────────────────────────────────────────────────
            Expanded(
              child: _query.isNotEmpty
                  ? _ResultsList(
                      results: _results,
                      onTap: (track) => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TrackViewScreen(track: track),
                        ),
                      ),
                    )
                  : _HistoryList(
                      history: _history,
                      onRemove: _removeHistory,
                      onTap: (q) {
                        _controller.text = q;
                        _startSearch();
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── History list ───────────────────────────────────────────────────────────────

class _HistoryList extends StatelessWidget {
  final List<String> history;
  final void Function(String) onRemove;
  final void Function(String) onTap;

  const _HistoryList({
    required this.history,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        Text(
          'History',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 20),
        ...history.map(
          (item) => _HistoryRow(
            text: item,
            onTap: () => onTap(item),
            onRemove: () => onRemove(item),
          ),
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _HistoryRow({
    required this.text,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(
                Icons.close,
                color: AppColors.textSecondary,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Results list ───────────────────────────────────────────────────────────────

class _ResultsList extends StatelessWidget {
  final List<MockTrack> results;
  final void Function(MockTrack) onTap;

  const _ResultsList({required this.results, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const Center(
        child: Text(
          'No results',
          style: TextStyle(
            fontFamily: AppFonts.sans,
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: results.length,
      itemBuilder: (context, i) {
        final track = results[i];
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onTap(track),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Thumbnail(size: 46, borderRadius: 6),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        style: const TextStyle(
                          fontFamily: AppFonts.sans,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${track.song}  •  ${track.artist}',
                        style: const TextStyle(
                          fontFamily: AppFonts.sans,
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
