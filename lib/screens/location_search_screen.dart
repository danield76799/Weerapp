import 'package:flutter/material.dart';

import '../services/location_service.dart';

class LocationSearchScreen extends StatefulWidget {
  const LocationSearchScreen({super.key});

  @override
  State<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final _controller = TextEditingController();
  final _service = LocationService();
  bool _searching = false;
  String? _error;

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final result = await _service.searchLocation(q);
      if (!mounted) return;
      if (result == null) {
        setState(() {
          _searching = false;
          _error = 'Locatie niet gevonden';
        });
        return;
      }
      Navigator.pop(context, {
        'lat': result.lat,
        'lon': result.lon,
        'name': result.name,
      });
    } catch (e) {
      setState(() {
        _searching = false;
        _error = 'Zoeken mislukt: $e';
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zoek locatie')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Stad of adres',
                hintText: 'bijv. Laren, Amsterdam, Utrecht',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                errorText: _error,
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _search,
                      ),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _searching
                    ? null
                    : () async {
                        try {
                          final result = await _service.getCurrentLocation();
                          if (!mounted) return;
                          Navigator.pop(context, {
                            'lat': result.lat,
                            'lon': result.lon,
                            'name': result.name,
                          });
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Locatie: $e')),
                          );
                        }
                      },
                icon: const Icon(Icons.my_location),
                label: const Text('Gebruik mijn huidige locatie'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
