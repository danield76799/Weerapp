import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/home_screen.dart';

/// Eerste keer onboarding — uitleg over swipe, instellingen en features
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  final _pages = [
    _OnboardPage(
      icon: Icons.swipe,
      iconColor: const Color(0xFF49AFC2),
      title: 'Swipe tussen locaties',
      body: 'Veeg links of rechts om snel tussen je opgeslagen steden te wisselen.',
    ),
    _OnboardPage(
      icon: Icons.tune,
      iconColor: const Color(0xFFFF9800),
      title: 'Pas het aan',
      body: 'Activeer alleen de weer kaarten die je nuttig vindt in de instellingen.',
    ),
    _OnboardPage(
      icon: Icons.notifications_active,
      iconColor: const Color(0xFF4CAF50),
      title: 'Blijf op de hoogte',
      body: 'Ontvang eenMelding bij regen, hitte of een hoge UV-index.',
    ),
    _OnboardPage(
      icon: Icons.cloud_queue,
      iconColor: const Color(0xFF7E57C2),
      title: 'Klaar voor het weer',
      body: 'Voeg je eerste stad toe of gebruik je huidige locatie om te beginnen.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => _pages[i],
              ),
            ),
            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
                  width: _page == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _page == i
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface.withAlpha(60),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            // Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Row(
                children: [
                  if (_page > 0)
                    TextButton(
                      onPressed: () {
                        _controller.previousPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut);
                      },
                      child: const Text('Terug'),
                    )
                  else
                    const Spacer(),
                  FilledButton.icon(
                    onPressed: _finish,
                    icon: Icon(_page == _pages.length - 1
                        ? Icons.check
                        : Icons.skip_next),
                    label: Text(_page == _pages.length - 1 ? 'Beginnen' : 'Overslaan'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;

  const _OnboardPage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(40),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(icon, size: 50, color: iconColor),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            body,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(180),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}