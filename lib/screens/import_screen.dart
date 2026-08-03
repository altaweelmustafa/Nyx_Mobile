import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';

/// Dev-only tool: search a song, review the auto-fetched metadata/lyrics,
/// and import it into this app's catalog via the local nyx-orc pipeline
/// server (see ~/git/orc). Mirrors the "Import Track" tab in orc's web UI.
///
/// Because mockTracks is compiled Dart source (not a runtime database),
/// a freshly-imported track only shows up in *this running instance* after
/// a hot reload / restart -- the server already wrote it to mock_data.dart.
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  static const _baseUrl = 'http://localhost:5050';
  final _dio = Dio(BaseOptions(baseUrl: _baseUrl));

  final _queryController = TextEditingController();
  final _titleController = TextEditingController();
  final _artistController = TextEditingController();
  final _lyricsController = TextEditingController();

  bool _searching = false;
  String? _searchError;
  List<Map<String, dynamic>> _candidates = [];

  Map<String, dynamic>? _selectedRaw;
  String? _selectedQuery;
  Map<String, dynamic>? _preview;
  bool _loadingPreview = false;

  List<Map<String, dynamic>> _playlists = [];
  String? _playlistId;

  bool _importing = false;
  String? _resultMessage;
  bool _resultIsError = false;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _titleController.dispose();
    _artistController.dispose();
    _lyricsController.dispose();
    super.dispose();
  }

  Future<void> _loadPlaylists() async {
    try {
      final res = await _dio.get('/api/import/playlists');
      final list = (res.data['playlists'] as List).cast<Map>();
      setState(() {
        _playlists = list.map((e) => e.cast<String, dynamic>()).toList();
      });
    } catch (_) {
      // orc server may not be running yet; the user will see empty options.
    }
  }

  Future<void> _search() async {
    final q = _queryController.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _searching = true;
      _searchError = null;
      _candidates = [];
      _preview = null;
      _resultMessage = null;
    });
    try {
      final res = await _dio.get('/api/import/search', queryParameters: {'q': q});
      final list = (res.data['candidates'] as List).cast<Map>();
      setState(() {
        _candidates = list.map((e) => e.cast<String, dynamic>()).toList();
      });
    } on DioException catch (e) {
      setState(() {
        _searchError = e.response?.data is Map
            ? (e.response!.data['error']?.toString() ?? e.message)
            : 'Could not reach nyx-orc at $_baseUrl -- is it running? (${e.message})';
      });
    } finally {
      setState(() => _searching = false);
    }
  }

  Future<void> _selectCandidate(Map<String, dynamic> candidate) async {
    final query = '${candidate['artistName']} - ${candidate['trackName']}';
    setState(() {
      _selectedRaw = candidate['raw'] as Map<String, dynamic>?;
      _selectedQuery = query;
      _loadingPreview = true;
      _preview = null;
      _resultMessage = null;
    });
    try {
      final res = await _dio.post(
        '/api/import/preview',
        data: {'query': query, 'raw': _selectedRaw},
      );
      final data = (res.data as Map).cast<String, dynamic>();
      setState(() {
        _preview = data;
        _titleController.text = data['title'] ?? '';
        _artistController.text = data['artist'] ?? '';
        _lyricsController.text = data['lyrics_plain'] ?? data['lyrics_synced'] ?? '';
      });
    } on DioException catch (e) {
      setState(() {
        _resultIsError = true;
        _resultMessage = e.response?.data is Map
            ? (e.response!.data['error']?.toString() ?? e.message)
            : 'Preview failed: ${e.message}';
      });
    } finally {
      setState(() => _loadingPreview = false);
    }
  }

  Future<void> _finalize() async {
    if (_selectedQuery == null) return;
    setState(() {
      _importing = true;
      _resultMessage = null;
    });

    final hasSynced = _preview?['has_synced_lyrics'] == true;
    final lyricsEdited = _lyricsController.text.trim();
    final originalLyrics =
        (_preview?['lyrics_plain'] ?? _preview?['lyrics_synced'] ?? '').toString().trim();

    final payload = <String, dynamic>{
      'query': _selectedQuery,
      'raw': _selectedRaw,
      'title': _titleController.text.trim(),
      'artist': _artistController.text.trim(),
      'playlist_id': _playlistId,
    };
    if (lyricsEdited.isNotEmpty && lyricsEdited != originalLyrics) {
      payload[hasSynced ? 'lyrics_synced' : 'lyrics_plain'] = lyricsEdited;
    }

    try {
      final res = await _dio.post('/api/import/finalize', data: payload);
      final result = (res.data['result'] as Map).cast<String, dynamic>();
      final warnings = (result['warnings'] as List?)?.cast<String>() ?? [];
      setState(() {
        _resultIsError = false;
        _resultMessage =
            "Imported '${result['title']}' by ${result['artist']} as track #${result['track_id']}."
            "${warnings.isNotEmpty ? '\n${warnings.join('\n')}' : ''}"
            '\n\nHot reload the app to see it in mockTracks.';
      });
    } on DioException catch (e) {
      setState(() {
        _resultIsError = true;
        _resultMessage = e.response?.data is Map
            ? (e.response!.data['error']?.toString() ?? e.message)
            : 'Import failed: ${e.message}';
      });
    } finally {
      setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(title: const Text('Import Track')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Searches iTunes for metadata/cover art and lrclib.net for lyrics, '
              'via the local nyx-orc server (localhost:5050). Dev tool -- not shipped to users.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    onSubmitted: (_) => _search(),
                    decoration: const InputDecoration(labelText: 'SEARCH', hintText: 'Artist - Title'),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _searching ? null : _search,
                  style: ElevatedButton.styleFrom(minimumSize: const Size(90, 50)),
                  child: _searching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background),
                        )
                      : const Text('Search'),
                ),
              ],
            ),
            if (_searchError != null) ...[
              const SizedBox(height: 12),
              Text(_searchError!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            ..._candidates.map(
              (c) => _CandidateTile(
                candidate: c,
                selected: identical(c['raw'], _selectedRaw),
                onTap: () => _selectCandidate(c),
              ),
            ),
            if (_loadingPreview) const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            if (_preview != null) _buildReview(context),
          ],
        ),
      ),
    );
  }

  Widget _buildReview(BuildContext context) {
    final preview = _preview!;
    final hasSynced = preview['has_synced_lyrics'] == true;
    final hasPlain = (preview['lyrics_plain'] as String?)?.isNotEmpty == true;
    final artworkUrl = preview['artwork_url'] as String?;

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: artworkUrl != null
                    ? Image.network(artworkUrl, width: 88, height: 88, fit: BoxFit.cover)
                    : Container(width: 88, height: 88, color: AppColors.surfaceHigh),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: [
                    TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'TITLE')),
                    const SizedBox(height: 10),
                    TextField(controller: _artistController, decoration: const InputDecoration(labelText: 'ARTIST')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            hasSynced
                ? 'Synced lyrics found on lrclib.net -- will be used as-is.'
                : hasPlain
                    ? 'Plain lyrics only -- will be force-aligned to the audio (nyx-orc/Whisper).'
                    : 'No lyrics found -- edit query, or paste your own below.',
            style: TextStyle(
              fontSize: 12,
              color: hasSynced || hasPlain ? AppColors.accent : Colors.orangeAccent,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _lyricsController,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'LYRICS'),
          ),
          if (preview['preview_url'] == null) ...[
            const SizedBox(height: 8),
            const Text(
              'No preview audio available for this match.',
              style: TextStyle(fontSize: 12, color: Colors.redAccent),
            ),
          ],
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _playlistId,
            decoration: const InputDecoration(labelText: 'PLAYLIST'),
            items: [
              const DropdownMenuItem(value: null, child: Text('(none)')),
              ..._playlists.map(
                (p) => DropdownMenuItem(value: p['id'] as String, child: Text('${p['name']} (${p['id']})')),
              ),
            ],
            onChanged: (v) => setState(() => _playlistId = v),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _importing ? null : _finalize,
            child: _importing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background),
                  )
                : const Text('Import into brager'),
          ),
          if (_resultMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _resultMessage!,
              style: TextStyle(
                fontSize: 13,
                color: _resultIsError ? Colors.redAccent : Colors.lightGreenAccent,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  final Map<String, dynamic> candidate;
  final bool selected;
  final VoidCallback onTap;

  const _CandidateTile({required this.candidate, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final artworkUrl = candidate['artworkUrl100'] as String?;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceHigh : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? AppColors.accent : AppColors.divider),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: artworkUrl != null
                  ? Image.network(artworkUrl, width: 40, height: 40, fit: BoxFit.cover)
                  : Container(width: 40, height: 40, color: AppColors.surfaceHigh),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    candidate['trackName']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    [candidate['artistName'], candidate['collectionName']]
                        .where((e) => e != null)
                        .join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}
