"""Dopasowuje wygenerowany (flutter create) projekt Android do builda release.

ML Kit używa refleksji, więc zaciemnianie/odchudzanie kodu przez R8 psuje
rozpoznawanie tekstu. Wyłączamy je i dodajemy reguły ochronne.
"""
import pathlib
import re

RULES = """-dontwarn com.google.mlkit.vision.text.**
-dontobfuscate
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
"""

app = pathlib.Path("android/app")
(app / "proguard-rules.pro").write_text(RULES)

kts = app / "build.gradle.kts"
groovy = app / "build.gradle"

if kts.exists():
    path = kts
    marker = 'signingConfig = signingConfigs.getByName("debug")'
    extra = [
        "isMinifyEnabled = false",
        "isShrinkResources = false",
        'proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), '
        '"proguard-rules.pro")',
    ]
elif groovy.exists():
    path = groovy
    marker = "signingConfig signingConfigs.debug"
    extra = [
        "minifyEnabled false",
        "shrinkResources false",
        "proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), "
        "'proguard-rules.pro'",
    ]
else:
    raise SystemExit("Nie znaleziono android/app/build.gradle(.kts)")

text = path.read_text()
if "proguard-rules.pro" not in text:
    if marker not in text:
        raise SystemExit(f"Brak oczekiwanego fragmentu w {path}: {marker}")
    text = re.sub(
        r"^(\s*)" + re.escape(marker),
        lambda m: m.group(0) + "".join("\n" + m.group(1) + line for line in extra),
        text,
        count=1,
        flags=re.M,
    )
    path.write_text(text)

# Nazwa aplikacji na ekranie telefonu.
manifest = app / "src/main/AndroidManifest.xml"
if manifest.exists():
    m = manifest.read_text()
    manifest.write_text(re.sub(r'android:label="[^"]*"', 'android:label="LabelCheck"', m, count=1))

print(f"Zaktualizowano {path}:")
print(text)
