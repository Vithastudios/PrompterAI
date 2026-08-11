# AUDIT — Prompter AI v2.0 → Nivel "Dios"

> Fecha: 2026-08-10 / Actualizado: 2026-08-11
> Estado: Auditoría realizada sobre el código real.
> Objetivo: llevar el sistema a 100% producción / "nivel dios".

---

## 🧪 RE-AUDITORÍA A FONDO (2026-08-11) — 100% del código leído

Hallazgos de puntos débiles reales encontrados al leer **todos** los archivos Swift.
Prioridad: 🔴 crash/grave · 🟠 riesgo · 🟡 táctica.

### 🔴 CRASH / GRAVES
- [x] **A1. Race en `beginSessionIfNeeded`** — `startTime`+`startSession` ahora bajo `writerLock`
      y se inicia la sesión exactamente una vez con el timestamp del primer buffer real.
      Además `startRecording` ahora publica `isRecording`/`assetWriter`/`videoInput`/
      `audioInput`/`startTime` bajo el lock (visibilidad de memoria correcta) y limpia
      estado si `startWriting()` falla. ✅
- [x] **A2. Reconfiguración de sesión en `startRecording`** — preset cambiado en caliente con
      `beginConfiguration/commitConfiguration` SIN detener/reiniciar la sesión (evita
      frames muertos y sesión inválida). Rotación/mirror solo si cambiaron. ✅
- [x] **A3. `armv7` → `arm64`** en Info.plist `UIRequiredDeviceCapabilities`. ✅

### 🟠 RIESGO
- [x] **A4. `onPositionChanged` se despacha a main** (NeuralFlowEngine). ✅
- [x] **A5. `autoreleasepool` en `AudioEngine.consumeSampleBuffer`** ✅
- [x] **A6. `ScrollEngine.attach` idempotente (invalida displayLink previo)** ✅
- [x] **A11. BUG: deteccion de hardware por nombre comercial** (`machineName()` devolvia
      "iPhone15,2" pero se comparaba con "iphone15pro"). Reescríto `VideoPresetResolver`
      para mapear por identificadores reales de hardware (iPhone16,x/17,x = ultra;
      iPhone14,x/15,2..15,5 = 1080p60). ✅
- [x] **A12. `NeuralFlowEngine` ahora es thread-safe** (NSLock): `processDetectedWord` corre en
      el hilo de audio mientras `syncPosition`/lecturas corren en main. Se añadió
      `readingIndex()` para lectura segura y se consolidaron callbacks en main. ✅

### 🟡 TÁCTICAS
- [x] **A7. `lastPosition` se guarda/restaura por guion** (`loadScriptIntoTeleprompter`,
      `saveCurrentPosition`, `restorePosition` con offsets UTF-16 correctos). ✅
- [ ] **A8. `energyThreshold` se lee en `handleSpeechResult` del valor `audioEnergy` que se
      publica de forma asíncrona** (posible desfase de 1 frame). Aceptable, pero documentar.
- [ ] **A9. Textos/UI hard-codeados en español** (PRO, Play/Pause, mensajes). i18n parcial.
- [ ] **A10. `currentSpeed` se lee desde hilos de audio en `setupBindings`** (safe por el
      dispatch a main en onSpeedAdjustment, pero `onPauseDetected` igual). OK de momento.

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

## PENDIENTE (próximo, por prioridad)

Críticos de la re-auditoría ✅ RESUELTOS (A1–A6, A11, A12 + A7).
Restantes (táctica / menores):
- [ ] A8: energyThreshold desfase tolerable — documentar
- [ ] A9: i18n completo (textos hard-codeados en español)

Funcionalidades pendientes:
- [ ] F1: highlight de palabra activa + sincronización fina
- [ ] F4: freemium real (watermark quemado + tiers free/pro) — revisar
- [ ] Lista/export de videos grabados
- [ ] Compilar en Xcode (B1) y probar en dispositivo real
