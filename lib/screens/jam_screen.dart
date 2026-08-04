import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/jam_service.dart';
import '../widgets/app_scaffold.dart';

class JamScreen extends StatefulWidget {
  const JamScreen({super.key});

  @override
  State<JamScreen> createState() => _JamScreenState();
}

class _JamScreenState extends State<JamScreen> {
  final _addressController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _startHosting(JamService jam) async {
    setState(() => _busy = true);
    await jam.startHosting();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _join(JamService jam) async {
    final address = _addressController.text.trim();
    if (address.isEmpty) return;
    setState(() => _busy = true);
    await jam.join(address);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final jam = context.watch<JamService>();

    return AppScaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 12),
                child: Text(
                  'Roll',
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildBody(jam)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(JamService jam) {
    switch (jam.role) {
      case JamRole.none:
        return _IdleBody(
          addressController: _addressController,
          busy: _busy,
          error: jam.error,
          onStartHosting: () => _startHosting(jam),
          onJoin: () => _join(jam),
        );
      case JamRole.host:
        return _StatusBody(
          statusTitle: 'Hosting a Roll',
          statusSubtitle: jam.listenerCount == 0
              ? 'Share your Tailscale IP with your friend so they can join.'
              : '${jam.listenerCount} listener${jam.listenerCount == 1 ? '' : 's'} following along.',
          actionLabel: 'Stop Roll',
          onAction: jam.disconnect,
        );
      case JamRole.client:
        return _StatusBody(
          statusTitle: 'In a Roll',
          statusSubtitle: "Mirroring ${jam.hostAddress}'s playback.",
          actionLabel: 'Leave Roll',
          onAction: jam.disconnect,
        );
    }
  }
}

class _RollPillButton extends StatelessWidget {
  final String label;
  final Color background;
  final VoidCallback? onPressed;

  const _RollPillButton({
    required this.label,
    required this.background,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        disabledBackgroundColor: background.withOpacity(0.5),
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 0,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: AppFonts.sans,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.background,
        ),
      ),
    );
  }
}

class _IdleBody extends StatelessWidget {
  final TextEditingController addressController;
  final bool busy;
  final String? error;
  final VoidCallback onStartHosting;
  final VoidCallback onJoin;

  const _IdleBody({
    required this.addressController,
    required this.busy,
    required this.error,
    required this.onStartHosting,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 32),

        // ── Icon ────────────────────────────────────────────────────────
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: Icon(Icons.podcasts, color: AppColors.textSecondary, size: 36),
          ),
        ),

        const SizedBox(height: 32),

        // ── Description ────────────────────────────────────────────────
        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            style: TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 15,
              height: 1.5,
              color: AppColors.textPrimary,
            ),
            children: [
              TextSpan(text: 'Listen together through '),
              TextSpan(text: 'Tailscale', style: TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: '.\nOne device hosts a '),
              TextSpan(text: 'Roll', style: TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: ' and the other joins it'),
            ],
          ),
        ),

        const SizedBox(height: 40),

        // ── Host ────────────────────────────────────────────────────────
        _RollPillButton(
          label: 'Host a Roll',
          background: AppColors.accent,
          onPressed: busy ? null : onStartHosting,
        ),

        const SizedBox(height: 56),

        // ── Join ────────────────────────────────────────────────────────
        TextField(
          controller: addressController,
          style: const TextStyle(fontFamily: AppFonts.sans, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Tailscale IP',
            hintStyle: const TextStyle(fontFamily: AppFonts.sans, color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.surfaceHigh,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        _RollPillButton(
          label: 'Join a Roll',
          background: AppColors.textPrimary,
          onPressed: busy ? null : onJoin,
        ),

        if (error != null) ...[
          const SizedBox(height: 16),
          Text(error!, style: const TextStyle(fontFamily: AppFonts.sans, fontSize: 12, color: Colors.redAccent)),
        ],
      ],
    );
  }
}

class _StatusBody extends StatelessWidget {
  final String statusTitle;
  final String statusSubtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _StatusBody({
    required this.statusTitle,
    required this.statusSubtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Icon(Icons.podcasts, color: AppColors.accent, size: 36),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            statusTitle,
            style: const TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              statusSubtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: AppFonts.sans, fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 200,
            child: _RollPillButton(label: actionLabel, background: AppColors.textPrimary, onPressed: onAction),
          ),
        ],
      ),
    );
  }
}
