import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart' show launchUrl;

import '../services/weather_service.dart';
import 'home_screen.dart';

class ApiKeyScreen extends StatefulWidget {
  const ApiKeyScreen({super.key});

  @override
  State<ApiKeyScreen> createState() => _ApiKeyScreenState();
}

class _ApiKeyScreenState extends State<ApiKeyScreen> {
  final _controller = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    context.read<WeatherService>().getApiKey().then((key) {
      if (mounted && key != null) {
        setState(() => _controller.text = key);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final key = _controller.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Vul een API key in');
      return;
    }
    if (key.length < 20) {
      setState(() => _error = 'API key lijkt te kort (OpenWeather keys zijn 32 tekens)');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<WeatherService>().setApiKey(key);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Opslaan mislukt: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('API Key instellen')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.wb_sunny, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Welkom bij Weerapp',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'Om het weer op te halen heb je een gratis OpenWeather API key nodig. '
              'Registreer op openweathermap.org, maak een gratis account aan en kopieer je key.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hoe kom ik aan een key?',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text('1. Ga naar openweathermap.org en registreer'),
                  const Text('2. Bevestig je e-mail'),
                  const Text('3. Kopieer je API key uit het dashboard'),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse('https://openweathermap.org/api')),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Open openweathermap.org'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'API Key',
                hintText: 'Plak je 32-tekens sleutel hier',
                border: const OutlineInputBorder(),
                errorText: _error,
                prefixIcon: const Icon(Icons.key),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _controller.clear(),
                      )
                    : null,
              ),
              onChanged: (_) => setState(() => _error = null),
              autocorrect: false,
              enableSuggestions: false,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: const Text('Opslaan en doorgaan'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Je key wordt alleen lokaal opgeslagen op je telefoon. '
              'Gratis tier: 1000 calls/dag (ruim voldoende voor 14-daagse forecast).',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurface.withAlpha(150)),
            ),
          ],
        ),
      ),
    );
  }
}
