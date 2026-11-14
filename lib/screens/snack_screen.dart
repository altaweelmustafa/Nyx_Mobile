import 'package:flutter/material.dart';

import '../services/snack_presence_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/nyx_toast.dart';

/// Link Nyx to Snack so your Snack profile shows "Listening to Nyx".
class SnackScreen extends StatefulWidget {
  const SnackScreen({super.key});

  @override
  State<SnackScreen> createState() => _SnackScreenState();
}

class _SnackScreenState extends State<SnackScreen> {
  final _snack = SnackPresenceService.instance;
  late final _keyController = TextEditingController(text: _snack.linkKey ?? '');
  late final _urlController = TextEditingController(text: _snack.url);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _keyController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _link() async {
    if (_keyController.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await _snack.link(_keyController.text, _urlController.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
    if (err == null) NyxToast.show(context, 'Linked to Snack', icon: Icons.link);
  }

  Future<void> _unlink() async {
    setState(() => _busy = true);
    await _snack.unlink();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _keyController.clear();
    });
    NyxToast.show(context, 'Unlinked from Snack', icon: Icons.link_off);
  }

  InputDecoration _field(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.surfaceHigh,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );

  static const _label = TextStyle(
    fontFamily: AppFonts.mono,
    fontSize: 11,
    letterSpacing: 1.2,
    color: AppColors.textSecondary,
  );

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: SafeArea(
        child: ListView(
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
                    'Snack',
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
                'Shows "Listening to Nyx" with the song you\'re playing on your Snack profile. '
                'It clears when you pause. In Snack, open Settings → Connections and copy your link key.',
                style: TextStyle(fontFamily: AppFonts.sans, fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 28),
            const Text('LINK KEY', style: _label),
            const SizedBox(height: 8),
            TextField(
              controller: _keyController,
              autocorrect: false,
              enableSuggestions: false,
              style: const TextStyle(fontFamily: AppFonts.mono, color: AppColors.textPrimary),
              decoration: _field('snk_…'),
            ),
            const SizedBox(height: 20),
            const Text('SNACK ADDRESS', style: _label),
            const SizedBox(height: 8),
            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              autocorrect: false,
              style: const TextStyle(fontFamily: AppFonts.sans, color: AppColors.textPrimary),
              decoration: _field(SnackPresenceService.defaultUrl),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _busy ? null : _link,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background),
                    )
                  : Text(_snack.isLinked ? 'Save' : 'Link'),
            ),
            if (_snack.isLinked) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _busy ? null : _unlink,
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: const Text('Unlink'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(fontFamily: AppFonts.sans, fontSize: 13, color: Colors.redAccent)),
            ],
          ],
        ),
      ),
    );
  }
}
