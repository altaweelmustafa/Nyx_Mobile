import 'package:flutter/material.dart';
import '../repositories/profile_repository.dart';
import '../services/catalog_sync_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final _profileRepo = ProfileRepository();
  final _syncService = CatalogSyncService();
  final _urlController = TextEditingController();

  bool _loading = true;
  bool _syncing = false;
  String? _resultMessage;
  bool _resultIsError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final url = await _profileRepo.getServerUrl();
    if (!mounted) return;
    setState(() {
      _urlController.text = url;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _sync() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _syncing = true;
      _resultMessage = null;
    });

    try {
      await _profileRepo.setServerUrl(url);
      final result = await _syncService.syncFromServer(url);
      if (!mounted) return;
      setState(() {
        _resultIsError = false;
        _resultMessage = result.total == 0
            ? 'Server has no tracks in its catalog yet.'
            : 'Synced ${result.total} track${result.total == 1 ? '' : 's'} -- '
                '${result.added} new, ${result.updated} updated.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resultIsError = true;
        _resultMessage = 'Sync failed: could not reach $url. Is the server running and are you on the tailnet?';
      });
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Text(
                          'Sync Library',
                          style: TextStyle(
                            fontFamily: AppFonts.sans,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'Pulls in everything imported on the homelab server\'s catalog. Safe to run '
                      'repeatedly -- already-synced tracks just get refreshed, never duplicated.',
                      style: TextStyle(fontFamily: AppFonts.sans, fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'SERVER URL',
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 11,
                      letterSpacing: 1.2,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _urlController,
                    keyboardType: TextInputType.url,
                    style: const TextStyle(fontFamily: AppFonts.sans, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'http://100.105.90.110:8086',
                      filled: true,
                      fillColor: AppColors.surfaceHigh,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _syncing ? null : _sync,
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    child: _syncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background),
                          )
                        : const Text('Sync Now'),
                  ),
                  if (_resultMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _resultMessage!,
                      style: TextStyle(
                        fontFamily: AppFonts.sans,
                        fontSize: 13,
                        color: _resultIsError ? Colors.redAccent : Colors.lightGreenAccent,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
