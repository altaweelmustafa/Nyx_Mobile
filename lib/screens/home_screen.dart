import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';
import '../widgets/thumbnail.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 160),
          children: [
            const SizedBox(height: 24),

            // ── For You ──────────────────────────────────────────────────────
            _SectionHeader(title: 'For You'),
            const SizedBox(height: 16),
            _HorizontalCardRow(
              items: mockForYouCards,
              onTap: (_) {},
            ),

            const SizedBox(height: 32),

            // ── Suggestions ──────────────────────────────────────────────────
            _SectionHeader(title: 'Suggestions'),
            const SizedBox(height: 16),
            _HorizontalCardRow(
              items: mockSuggestions,
              onTap: (_) {},
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    );
  }
}

// ── Horizontal scrollable card row ─────────────────────────────────────────────

class _HorizontalCardRow extends StatelessWidget {
  final List<String> items;
  final void Function(String) onTap;

  const _HorizontalCardRow({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        itemBuilder: (context, i) {
          return Padding(
            padding: EdgeInsets.only(right: i < items.length - 1 ? 12 : 0),
            child: GestureDetector(
              onTap: () => onTap(items[i]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Thumbnail(size: 120, borderRadius: 10),
                  const SizedBox(height: 8),
                  Text(
                    items[i],
                    style: const TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
