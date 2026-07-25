import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'shell_screen.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();

  void _navigate() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ShellScreen()),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 60),

              // ── Logo ────────────────────────────────────────────────────────
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.accent, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'B',
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── Tagline ─────────────────────────────────────────────────────
              const Text(
                'Free Music.\nNo Ads.\nFor Everyone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
              ),

              const Spacer(),

              // ── Email field ─────────────────────────────────────────────────
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(
                  fontFamily: AppFonts.sans,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  labelText: 'EMAIL',
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
                  contentPadding: const EdgeInsets.fromLTRB(14, 20, 14, 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Password field ──────────────────────────────────────────────
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(
                  fontFamily: AppFonts.sans,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  labelText: 'PASSWORD',
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
                  contentPadding: const EdgeInsets.fromLTRB(14, 20, 14, 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Log in ──────────────────────────────────────────────────────
              OutlinedButton(
                onPressed: _navigate,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.divider),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: const Text('Log in'),
              ),

              const SizedBox(height: 12),

              // ── Continue with Google ────────────────────────────────────────
              OutlinedButton(
                onPressed: _navigate,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.divider),
                  minimumSize: const Size(double.infinity, 50),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      // Google logo far left
                      Image.asset(
                        'assets/icons/google.png',
                        width: 20,
                        height: 20,
                      ),
                      // Text centered in remaining space
                      const Expanded(
                        child: Text(
                          'Continue with Google',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppFonts.sans,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      // Invisible balancer so text is truly centered
                      const SizedBox(width: 20),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Sign up ─────────────────────────────────────────────────────
              ElevatedButton(
                onPressed: _navigate,
                child: const Text('Sign up'),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
