# LabelCheck

Aplikacja mobilna (Flutter) dla inspekcji jakości artykułów handlowych i rolno-spożywczych:
zdjęcie listy składników → OCR (Google ML Kit, offline) → ręczna korekta → lista składników
z wykrytymi numerami E.

## Stan projektu

- [x] Zdjęcie / wybór z galerii, OCR, edytowalny tekst
- [x] Parser składników (nawiasy, procenty, numery E, poprawki typowych pomyłek OCR)
- [x] Testy parsera, workflow GitHub Actions budujący APK
- [x] Mechanizm sprawdzania E-numerów (`assets/additives.json`, `lib/checker.dart`)
- [ ] Pełna baza dodatków z EU Food Additives Database (obecnie tylko dane przykładowe, `meta.sample = true`)
- [ ] Alergeny i reguły oznakowania (rozporządzenie 1169/2011)
- [ ] Historia kontroli, eksport raportu do PDF, synchronizacja z backendem PHP
- [ ] iOS (wymaga Maca z Xcode)

## Uruchomienie lokalnie

```bash
flutter create . --platforms=android --project-name label_check --org pl.fableinside
rm -f test/widget_test.dart
flutter pub get
flutter test
flutter run
```

Folder `android/` jest generowany przez `flutter create` (workflow robi to sam, jeśli go brakuje).

## CI

Każdy push na `main` uruchamia `flutter analyze`, `flutter test` i buduje APK
(artefakt `label-check-apk` w zakładce Actions).

Wynik aplikacji ma charakter informacyjny i nie zastępuje decyzji inspektora.
