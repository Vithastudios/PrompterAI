# AUDIT — Prompter AI v2.0 → Nivel "Dios"

> Fecha: 2026-08-10 / Actualizado: 2026-08-11
> Estado: Auditoría realizada sobre el código real.
> Objetivo: llevar el sistema a 100% producción / "nivel dios".

---

## 🔴 BLOQUEANTES

- [ ] **B1**. Crear `.xcodeproj` (en Xcode, en Mac) — ver `MOUNTING_GUIDE.md`
- [x] **B2**. Modelo CoreData `.xcdatamodeld` con `ScriptEntity` creado y añadido.
- [x] **B3**. `updatedAt` se setea en create/update → orden estable.

## 🟠 ARQUITECTURA

- [ ] **F1. Posición única de lectura.** Existe `syncPosition` + matching fuzzy
      bidireccional, pero falta: highlight de la palabra activa + timestamped
      sincronización fina con el offset de scroll. (Parcial)
- [x] **F2. Audio en la grabación.** Captura única de mic enrutada a
      `SFSpeechAudioBufferRecognitionRequest` Y a la pista de audio del
      `AVAssetWriter`. (Hecho 2026-08-10)
- [x] **F3. Matching fuzzy + bidireccional + avance por offset.** Implementado
      con Levenshtein y ventanas de búsqueda. (Hecho en fases 2a/2b)
- [x] **F4. Freemium real.** Marca de agua quemada en video (free) vía
      `Watermarker` + tiers 1080p30 free / calidad por hardware pro.
      Botón PRO + Paywall conectado.

## 🟡 TÁCTICAS

- [x] Pausa por puntuación — `predictPauseNeeded`
- [x] Scroll manual (UIPanGestureRecognizer)
- [x] Video desorientado — rotación + mirror front cam
- [x] `energyThreshold` calibrado adaptativamente (piso de ruido móvil/EAM)
- [x] Guardar video en Fotos (PHPhotoLibrary) + feedback UI
- [x] UI importar/lista/editar guiones (CoreData) + settings (fuente/color/idioma)
- [x] Presets adaptativos por dispositivo (4K60/1080p60/1080p30)
- [x] `handleTransaction(.failed)` ya no desactiva premium; verifyStatus idempotente
- [x] i18n idioma de voz seleccionable (Settings)
- [x] Manejo de errores en UI (alertas) — ya no solo `print`

## 🚀 PLAN A 100% (orden de impacto)

**Fase 1 — Compilar y estable** ✅ salvo `.xcodeproj`
- xcdatamodeld + updatedAt ✅
- Manejo de errores real ✅

**Fase 2 — Núcleo** ✅
- Audio en grabación ✅ · Presets adaptativos ✅ · Matching fuzzy ✅

**Fase 3 — Producto** (parcial)
- Guardar en Fotos ✅ · Importar/lista/editor/settings ✅
- Falta: lista/export de videos · **Freemium real (watermark + tiers)**

**Fase 4 — Polishing** ✅
- Dedupe/calibración RMS ✅ · i18n ✅ · fix SubscriptionManager ✅

---

## PENDIENTE (próximo)

- [ ] F1: highlight de palabra activa + sincronización fina
- [ ] F4: freemium real (watermark quemado + tiers free/pro)
- [ ] Lista/export de videos grabados
- [ ] Compilar en Xcode (B1) y probar en dispositivo real
