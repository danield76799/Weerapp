# Weerapp

Een minimalistische weer-app voor Nederland, gebouwd met Flutter.

## Features

- **14-daagse weersverwachting** via OpenWeather One Call API 3.0
- **UV-index prominent** met risicokleuren (laag/matig/hoog/zeer hoog/extreem)
- **Locatie via GPS** of zoeken op naam
- **Offline caching** — werkt zonder internet met de laatst opgehaalde data
- **Notificaties** bij UV ≥ 7 of temperatuur < 0°C of > 30°C
- **Material 3** met AMOLED pure black dark mode

## Setup

1. Maak een gratis account op [openweathermap.org](https://openweathermap.org/api)
2. Kopieer je API key uit het dashboard
3. Open de app en plak je key

Gratis tier: 1000 calls/dag (ruim voldoende voor 14-daagse forecast).

## Build

```bash
flutter pub get
flutter build appbundle --release
```

## Tech stack

- Flutter 3.44
- Material 3 + Provider
- Dio (HTTP)
- Geolocator + Geocoding
- SharedPreferences (caching)
- flutter_local_notifications (alerts)

## License

Privé — © Daan
