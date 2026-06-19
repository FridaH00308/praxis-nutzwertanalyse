# Nutzwertanalyse / Stärken- & Kompetenzprofil – Praxis-Web-App

Eine Web-App für Zahnarztpraxen: Die Führungskraft bewertet Mitarbeiter nach
dem Kriterienkatalog (Gewichtung × Bewertung = Nutzwert), Mitarbeiter geben
eine Selbsteinschätzung ab, am Ende erzeugt die Führungskraft ein Word-Dokument.

- **Kostenlos** (GitHub Pages + Supabase Free Tier)
- **Geräteübergreifend** (FK am PC, MA am Handy – gleiche Daten)
- **Datenschutz-sicher**: Mitarbeiter können die Bewertung der Führungskraft
  technisch nicht abrufen (serverseitig per Row Level Security geschützt)

---

## Überblick: Wer macht was?

| Teil | Was | Wo |
|---|---|---|
| **Datenbank + Accounts** | speichert alles zentral, Login, Passwort-Reset | Supabase (du legst es an) |
| **Website (Frontend)** | das, was man im Browser sieht | GitHub Pages (du lädst es hoch) |

Du brauchst **zwei kostenlose Konten**: bei [github.com](https://github.com)
und bei [supabase.com](https://supabase.com).

---

## Schritt 1 – Supabase-Projekt anlegen (die Datenbank)

1. Auf [supabase.com](https://supabase.com) registrieren und einloggen.
2. **"New project"** klicken.
   - Name: z. B. `praxis-nutzwertanalyse`
   - Datenbank-Passwort: ein sicheres Passwort vergeben (notieren!)
   - **Region: `Central EU (Frankfurt)`** wählen (wichtig für Datenschutz!)
3. Warten, bis das Projekt fertig eingerichtet ist (~2 Minuten).

### 1a – Tabellen & Sicherheit einrichten
4. Links im Menü auf **"SQL Editor"** → **"New query"**.
5. Den **kompletten Inhalt der Datei `database.sql`** hineinkopieren.
6. **"Run"** klicken. Es sollte ohne Fehler durchlaufen ("Success").

### 1b – E-Mail-Bestätigung anpassen (für MA-Schattenkonten)
7. Links **"Authentication"** → **"Sign In / Providers"** → **Email**.
8. **"Confirm email"** ausschalten (Mitarbeiter haben keine echte E-Mail).
   Die Führungskraft nutzt trotzdem eine echte E-Mail und kann ihr Passwort
   normal zurücksetzen.

### 1c – Server-Funktionen einrichten (MA-Login + Code-Verwaltung)
Im Ordner `functions/` liegen zwei Funktionen. Beide per Copy-Paste anlegen:
1. Links **"Edge Functions"** → **"Create a new function"**.
2. Name exakt **`employee-login`** → den Inhalt von
   `functions/employee-login/index.ts` einfügen → **"Deploy"**.
3. Nochmal **"Create a new function"**, Name exakt **`manage-employee`** →
   Inhalt von `functions/manage-employee/index.ts` einfügen → **"Deploy"**.

Es sind **keine** zusätzlichen Secrets nötig – Supabase stellt die nötigen
Schlüssel automatisch bereit. Den `service_role`-Key bekommst du nie zu Gesicht;
er wird nur intern in diesen Funktionen verwendet.

### 1d – Die zwei Zugangsdaten kopieren
9. Links **"Project Settings"** (Zahnrad) → **"API"**.
10. Notiere dir:
    - **Project URL** (z. B. `https://abcdxyz.supabase.co`)
    - **anon public** key (langer Text)

    Diese beiden Werte trägst du gleich in `config.js` ein. Sie sind **nicht
    geheim** – sie dürfen öffentlich im Frontend stehen. Den `service_role`-Key
    NIEMALS ins Frontend kopieren!

---

## Schritt 2 – config.js ausfüllen

Im Projektordner liegt `config.example.js`. Kopiere sie zu **`config.js`** und
trage deine zwei Werte aus Schritt 1d ein:

```js
window.APP_CONFIG = {
  SUPABASE_URL: "https://DEINPROJEKT.supabase.co",
  SUPABASE_ANON_KEY: "dein-anon-public-key",
};
```

---

## Schritt 3 – Website zu GitHub hochladen

**Einfachste Variante (ohne Terminal):**

1. Auf [github.com](https://github.com) → **"New repository"**.
   - Name: z. B. `praxis-nutzwertanalyse`
   - **Public** auswählen (für GitHub Pages auf Free Tier nötig)
   - **"Create repository"**.
2. Auf der nächsten Seite: **"uploading an existing file"** anklicken.
3. **Alle Dateien** aus diesem Ordner per Drag-and-Drop hineinziehen
   (`index.html`, `config.js`, evtl. weitere) → **"Commit changes"**.

---

## Schritt 4 – Online schalten (der teilbare Link)

1. Im Repository oben auf **"Settings"** → links **"Pages"**.
2. Unter **"Source"**: **"Deploy from a branch"**, Branch **`main`**,
   Ordner **`/ (root)`** → **"Save"**.
3. Nach 1–2 Minuten erscheint oben der Link:
   `https://DEINNAME.github.io/praxis-nutzwertanalyse/`
4. **Diesen Link verschickst du.** Fertig.

---

## Nutzung

- **Führungskraft**: registriert sich mit echter E-Mail + Passwort, legt die
  Praxis an, bekommt einen **Praxis-Code**, legt Mitarbeiter mit Namen +
  Zugangscode an, bewertet, **gibt für den MA frei**, sperrt bei Bedarf,
  schließt ab und lädt das **Word-Dokument** herunter.
- **Mitarbeiter**: öffnet denselben Link, wählt "Als Mitarbeiter anmelden",
  gibt **Praxis-Code + Name + Zugangscode** ein, füllt die Selbsteinschätzung
  aus. Sieht die FK-Bewertung **nicht** und kann **kein** Word erzeugen.

---

## Updates später einspielen

Datei im GitHub-Repository öffnen → Stift-Symbol → ändern → "Commit", oder
neue Version per "Upload files" hochladen. Die Seite aktualisiert sich
automatisch nach 1–2 Minuten.

---

## 🔒 Sicherheits-Test vor dem Echteinsatz

Bitte einmal durchspielen, bevor echte Daten erfasst werden:

1. Lege als FK eine Testpraxis + einen Test-Mitarbeiter an, erstelle einen
   Zyklus und trage **FK-Bewertungen** ein, aber **gib noch nicht frei** (Status „Entwurf").
2. Melde dich in einem **zweiten Browser/Privatfenster** als dieser Mitarbeiter
   an (Praxis-Code + Name + Code).
   - ✅ Der Zyklus darf **nicht** auftauchen (Entwurf ist unsichtbar).
3. Gib als FK frei (Status „Freigegeben"), prüfe als MA:
   - ✅ MA sieht den Zyklus, kann seine **Selbsteinschätzung** eintragen.
   - ✅ MA sieht **nirgends** die G-/B-Werte der Führungskraft und hat **keinen**
     „Word herunterladen"-Knopf.
4. Setze als FK auf „Gesperrt" → als MA dürfen keine Änderungen mehr möglich sein.

Wenn alle vier Punkte stimmen, greifen die serverseitigen Schutzregeln korrekt.

## ⚠️ Datenschutz (DSGVO)

Es werden Leistungsbeurteilungen von Mitarbeitern verarbeitet (Personaldaten).
- Supabase-Region **Frankfurt** verwenden.
- Mit Supabase einen **Auftragsverarbeitungsvertrag (AVV/DPA)** abschließen
  (im Supabase-Dashboard verfügbar).
- Mitarbeiter vorab informieren und Zweck/Speicherung transparent machen.
- Diese App ersetzt keine arbeitsrechtliche/datenschutzrechtliche Beratung.
