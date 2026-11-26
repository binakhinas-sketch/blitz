# ⚡️ Blitz – deine eigene Snap-App fürs iPhone

**Funktionen:** Kamera (vorne/hinten, Blitz, Pinch-Zoom, Doppeltippen zum Wechseln) · 11 Live-Filter (zum Wechseln wischen) · Text auf dem Snap · Timer (1–10 s oder ∞) · Snaps, die nach dem Ansehen verschwinden · Screenshot-Erkennung · Chats mit Streaks 🔥 · Stories (24 h) · Erinnerungen + Speichern in Fotos · Profil mit Avatar und Blitz-Score · Bilder aus der Galerie senden

> Die Freunde sind simuliert: Sie antworten automatisch mit Nachrichten und Snaps. Für echte Chats zwischen mehreren Handys bräuchte die App einen Server.

---

## 1. IPA bauen lassen (kostenlos, über GitHub)

1. Erstelle ein Konto auf **github.com** und klicke auf **New repository** (z. B. Name `blitz`, *Public* ist am einfachsten).
2. Klicke auf **uploading an existing file** und zieh den **Inhalt** dieses Ordners hinein (`project.yml`, `Blitz/`, `.github/`, `README.md`). Dann auf **Commit changes** klicken.
   - Wichtig: Der Ordner `.github` muss mit hochgeladen werden, sonst startet kein Build.
3. Öffne den Tab **Actions**. Der Build „IPA bauen“ startet automatisch und dauert ca. 5 bis 10 Minuten.
4. Wenn der Haken grün ist, klicke auf den Lauf und lade unten bei **Artifacts** die Datei **Blitz-ipa** herunter. Entpacke sie, dann hast du **Blitz.ipa**.

Falls der Build rot wird: Klick auf den roten Schritt, kopier die Fehlermeldung und schick sie mir. Ich behebe den Fehler dann.

## 2. Mit Sideloadly aufs iPhone (unter Windows)

1. Installiere **iTunes** und **iCloud** direkt von apple.com (nicht die Versionen aus dem Microsoft Store).
2. Installiere **Sideloadly** (sideloadly.io).
3. Schließ das iPhone per USB an und tippe auf dem iPhone auf „Diesem Computer vertrauen“.
4. Zieh **Blitz.ipa** in Sideloadly, gib deine Apple-ID ein und klick auf **Start**.
5. Auf dem iPhone: **Einstellungen → Allgemein → VPN & Geräteverwaltung** → deine Apple-ID antippen → **Vertrauen**.
6. Der Developer Mode muss an sein. Das hast du ja schon erledigt ✅

Mit einer kostenlosen Apple-ID läuft die App **7 Tage**. Danach spielst du sie einfach nochmal mit Sideloadly auf. Deine Daten bleiben dabei erhalten.
