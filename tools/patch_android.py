"""Dopasowuje wygenerowany (flutter create) projekt Android do builda release.

Dodaje regułę R8 ignorującą brakujące klasy ML Kit dla alfabetów, z których
nie korzystamy (chiński, japoński, koreański, devanagari).
"""
import pathlib
import re

RULES = "-dontwarn com.google.mlkit.vision.text.**\n"

app = pathlib.Path("android/app")
(app / "proguard-rules.pro").write_text(RULES)

kts = app / "build.gradle.kts"
groovy = app / "build.gradle"

if kts.exists():
    path = kts
    marker = 'signingConfig = signingConfigs.getByName("debug")'
    extra = (
        'proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), '
        '"proguard-rules.pro")'
    )
elif groovy.exists():
    path = groovy
    marker = "signingConfig signingConfigs.debug"
    extra = (
        "proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), "
        "'proguard-rules.pro'"
    )
else:
    raise SystemExit("Nie znaleziono android/app/build.gradle(.kts)")

text = path.read_text()
if "proguard-rules.pro" not in text:
    if marker not in text:
        raise SystemExit(f"Brak oczekiwanego fragmentu w {path}: {marker}")
    text = re.sub(
        r"^(\s*)" + re.escape(marker),
        lambda m: m.group(0) + "\n" + m.group(1) + extra,
        text,
        count=1,
        flags=re.M,
    )
    path.write_text(text)

print(f"Zaktualizowano {path}:")
print(text)
