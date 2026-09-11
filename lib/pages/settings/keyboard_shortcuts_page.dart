import 'package:flutter/material.dart';

/// A reference list of the player's keyboard shortcuts -- split out of the
/// old "General & Data" catch-all so it reads as its own category, matching
/// Backup & Data getting the same treatment.
class KeyboardShortcutsPage extends StatelessWidget {
  const KeyboardShortcutsPage({super.key});

  static const _shortcuts = [
    ('Space / K', 'Play / Pause'),
    ('J', 'Seek -5s'),
    ('L', 'Seek +5s'),
    ('M', 'Mute'),
    ('F', 'Toggle fullscreen'),
    ('Esc', 'Back'),
    ('Tab', 'Focus hub switcher'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1017),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Keyboard Shortcuts', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF12151E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (key, action) in _shortcuts)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                key,
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(action, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
