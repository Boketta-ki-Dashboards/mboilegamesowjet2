# MIKRORAYON 77 — iPhone-Prototyp 0.3

Dieses Verzeichnis ist ein eigenständiges Xcode-Projekt. Kein Unity, Node, CocoaPods, kostenpflichtiges Asset-Paket oder Projektgenerator nötig. Swift, UIKit und SceneKit kommen mit Xcode. Die Szene ist echtes 3D mit eigenen modularen Wohnblöcken, Offiziersfigur, drei Bewohnern, Statue und Hofdetails. Modelle, Texturen und einfache Sounds liegen vollständig unter `Content/`. Die finale Grafikqualität der Referenzen und die vollständige Kampagne sind noch nicht umgesetzt.

## Auf dein iPhone installieren

1. Den Ordner vollständig auf deinem Mac entpacken. Aktuelles Xcode aus dem Mac App Store installieren und einmal öffnen (zusätzliche iOS-Komponenten installieren lassen). Mindestziel: iOS 16, iPhone, Hochkant.
2. `Mikrorayon77.xcodeproj` doppelklicken. Oben das Schema **Mikrorayon77** auswählen.
3. Im Projektnavigator das blaue Projekt auswählen, dann unter **TARGETS → Mikrorayon77 → Signing & Capabilities** dein **Team** wählen. Bei Bedarf deine Apple-ID unter **Xcode → Settings → Accounts** hinzufügen. **Automatically manage signing** aktiviert lassen.
4. Falls die Bundle-ID bereits vergeben ist, `com.mikrorayon77.courtyard` durch eine eigene eindeutige ID ersetzen, etwa `de.deinname.mikrorayon77`.
5. iPhone per Kabel verbinden, entsperren und dem Mac vertrauen. Unter **Einstellungen → Datenschutz & Sicherheit → Entwicklermodus** aktivieren, falls Xcode dazu auffordert; anschließend neu starten.
6. Oben in Xcode dein iPhone als Ziel wählen und **▶ Run** drücken. Falls nötig das Entwicklerprofil unter **Einstellungen → Allgemein → VPN und Geräteverwaltung** bestätigen.

Eine kostenlose Apple-ID reicht üblicherweise für eigene Gerätetests. Personal-Team-Signierungen laufen normalerweise nach sieben Tagen ab; dann erneut aus Xcode installieren. Xcode-Version und iPhone-iOS müssen kompatibel sein. Eine signierte IPA kann ohne deine Signing-Konfiguration nicht vorab geliefert werden.

## Testablauf (ca. 3 Minuten)

- Finger im Spielfeld ziehen: Figur läuft, Loslassen stoppt sie.
- Links in den Kreis **HOLZ** laufen: Holz stapelt sich am Rücken (maximal 15 Ressourcen).
- Zur orangefarbenen **HEIZUNG**: Holz wird automatisch abgegeben; Feuer und Fenster leuchten auf.
- Rechts bei **VORRÄTE** sechs Nahrung sammeln und zur **KANTINE** bringen.
- Zwölf Holz sammeln und zur **Werkstatt** links bringen: Wand und Dach entstehen sichtbar.
- Juri neben der Werkstatt ansprechen: Er übernimmt die Holzproduktion. Den Vorrat an der Werkstatt abholen.
- Mischa und Galina ansprechen; den Sockel der Lenin-Statue und das Schwarze Brett untersuchen.
- Ton über die Schaltfläche ein-/ausschalten.
- App kurz verlassen und wieder öffnen: Figur darf nicht weiterlaufen. App vollständig schließen und erneut öffnen: Ressourcen und Reparaturfortschritt sollen erhalten bleiben.

Bitte beim Feedback iPhone-Modell, iOS-Version, einen Screenshot und die konkrete Stelle nennen: Steuerung, Kamera, Lesbarkeit, Ablauf oder Leistung. Diese Version hat einfache Gelenkanimationen, Wind/Aktionsgeräusche und eine erste Arbeiter-Automatisierung. Die Modelle sind noch stilisierte Prototypen, keine fertigen Produktionsassets. Gebäudeflächen und Außenbegrenzungen blockieren Bewegung; kleine Dekorationsobjekte haben noch keine individuellen Kollisionskörper. Die große Kampagne ist noch nicht gebaut. Browser-Spielstände werden nicht importiert.

## Prüfstatus

Erstellt in einer Linux-Umgebung ohne Swift, Apple SDK oder Xcode. Gemeinsame Inhalte und die Aufgabenfolge wurden in einer Linux/Godot-Prüfumgebung ausgeführt. Diese Screenshots sind keine iPhone-Aufnahmen; dafür sind keine zusätzlichen Installationen auf deinem Mac nötig. Projektstruktur und Swift-Syntax werden hier statisch geprüft; ein erfolgreicher Apple-Build und ein Gerätetest sind **noch nicht bestätigt**. Für den Mac liegt `check-macos.sh` bei: `bash check-macos.sh` prüft die Simulationslogik und baut für den iOS-Simulator ohne Signierung. Das ist optional; der normale Weg bleibt das Öffnen und Starten in Xcode.

SceneKit ist seit Apples SDK-Generation 26 deprecated, funktioniert aber weiterhin auf dem iOS-16+-Ziel. Es ermöglicht diesen kompakten Xcode-Test ohne externe Engine. Vor einer langfristigen Produktionsentscheidung sollte RealityKit/Metal als Nachfolger bewertet werden; Simulationszustand und Spielregeln sind dafür vom Renderer getrennt.
