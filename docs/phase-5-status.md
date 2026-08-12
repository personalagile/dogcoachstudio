# Phase 5 – Status

Stand: 12. August 2026

## Implementierter Stand

- DCS-050: hundgebundene Pakete mit Einheitenart, Kauf-/Ablaufdatum, manuellem Zahlstatus und abgeleitetem Lifecycle
- DCS-051: Einheiten- und Wertcoupons mit Ablauf und genau einmaliger Einlösung
- DCS-052: append-only Ledger für Purchase, Adjustment, Redeem, Coupon und Reversal; Saldo ausschließlich aus Startwert plus Ledger
- DCS-053: deterministischer DE/EN-Report-Composer mit typseitiger Allowlist für Übungs-Snapshots und `clientFacingNote`
- DCS-054: Text- und mehrseitiger PDF-Export für A4/Letter, optionales Branding und systemisches Share Sheet
- Packages-Tab mit adaptiver Paketliste und Paketerstellung

## Verifikation

- [x] Phase-5-Domain-Suite: 8 Tests für Lifecycle, Coupon, Ledger, CSV, Privacy, Freigabe und PDF
- [x] Redeem je Attendance/Paket eindeutig; Korrektur ausschließlich durch Reversal
- [x] Coupon-Doppeleinlösung und abgelaufener Coupon abgelehnt
- [x] Privacy-Canary in DE und EN ausgeschlossen
- [x] Export vor Trainerfreigabe abgelehnt
- [x] lange Inhalte als mehrseitige A4- und Letter-PDFs gerendert
- [x] iPhone-Paket-UI-Smoke erfolgreich
- [x] iPad-Paket-UI-Smoke erfolgreich
- [x] vollständige Phase-0-bis-5-Suite: 61 Swift-Tests und 5 UI-Smokes erfolgreich

## Grenzen

- Keine StoreKit-Produkte oder Zahlungsabwicklung; Zahlstatus bleibt manuell.
- Keine Cloud-KI; Berichte bleiben vollständig lokal und deterministisch.
- PDF verwendet bewusst zurückhaltendes Textlayout; App-Store-Marketinglayout ist nicht Teil dieser Phase.
