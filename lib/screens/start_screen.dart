import 'package:flutter/material.dart';
import '../services/tailnet_service.dart';
import '../theme/app_theme.dart';
import 'shell_screen.dart';

/// Entry gate: instead of a credentialed login, this checks whether the
/// device is on the tailnet (see TailnetService) -- matches the trust model
/// the rest of the app already uses (Jam, the homelab sync server) since
/// there's no real backend to authenticate against anyway. Auto-advances
/// into the app the moment a tailnet IP is found.
class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  bool _checking = true;
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    final connected = await TailnetService.isOnTailnet();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _connected = connected;
    });
    if (connected) _navigate();
  }

  void _navigate() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const ShellScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: boundToDesktopWidth(
        context,
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        const SizedBox(height: 60),

                        // ── Logo ────────────────────────────────────────────────────────
                        Container(
                          width: 170,
                          height: 170,
                          padding: const EdgeInsets.all(20),
                          child: Image.asset('assets/icons/nyx_logo.png'),
                        ),

                        const SizedBox(height: 32),

                        // ── Tagline ─────────────────────────────────────────────────────
                        const Text(
                          'Free Music.\nNo Ads.\nFor Everyone.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppFonts.mono,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.5,
                          ),
                        ),

                        const Spacer(),

                        // ── Tailnet gate state ───────────────────────────────────────────
                        if (_checking)
                          const CircularProgressIndicator(
                            color: AppColors.accent,
                          )
                        else if (!_connected) ...[
                          const Icon(
                            Icons.wifi_off,
                            color: AppColors.textSecondary,
                            size: 32,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Not connected to the tailnet',
                            style: TextStyle(
                              fontFamily: AppFonts.sans,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Connect to Tailscale, then try again.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: AppFonts.sans,
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _check,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(200, 46),
                            ),
                            child: const Text('Try Again'),
                          ),
                        ],

                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
