# Weerapp

Een minimalistische weer-app voor Nederland, gebouwd met Flutter.

## Features

- **14-daagse weersverwachting** via [Open-Meteo](https://open-meteo.com/) — gratis, geen API key nodig
- **Uurlijkse verwachting** met temperatuur, neerslagkans en wind
- **UV-index** met risicokleuren (laag/matig/hoog/zeer hoog/extreem)
- **Luchtkwaliteit en pollen** via de Open-Meteo Air Quality API
- **Neerslagradar** met KNMI nowcast voor de komende uren
- **Buienkaart** met de eerstvolgende regen
- **Jas- en zonnebrandadvies** op basis van temperatuur, wind en UV
- **Weerhistorie en vergelijking** met vorige jaren
- **Locatie via GPS** of zoeken op naam, met meerdere opgeslagen locaties
- **Offline caching** — werkt zonder internet met de laatst opgehaalde data
- **Notificaties** bij regen, UV ≥ 7, vorst of hitte, plus een instelbare ochtendbriefing
- **Material 3** met licht en donker thema en instelbare accentkleur

## Setup

Er is geen API key of account nodig. Open-Meteo is gratis voor niet-commercieel
gebruik; de app doet direct requests naar `api.open-meteo.com`.

## Build

```bash
flutter pub get
flutter build appbundle --release
```

De CI bouwt de ondertekende APK's en AAB via GitHub Actions. Lokale
release-builds vallen terug op de debug-keystore en zijn niet bedoeld voor de
Play Store.

## Tech stack

- Flutter 3.47
- Material 3 + Provider
- Dio (HTTP)
- Geolocator + Geocoding
- SharedPreferences (caching)
- flutter_local_notifications + Workmanager (alerts)
- flutter_map + latlong2 (radar)

## License

Privé — © Daan
