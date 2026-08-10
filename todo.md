# AUDIT — Prompter AI v2.0 → Nivel "Dios"

> Fecha: 2026-08-10
> Estado: Auditoría realizada sobre el código real.
> Objetivo: llevar el sistema a 100% producción / "nivel dios".

---

## 🔴 BLOQUEANTES (no compila hoy)

- [ ] **B1**. Crear `.xcodeproj` (en Xcode, en Mac)
- [ ] **B2**. Crear modelo CoreData `.xcdatamodeld` con `ScriptEntity`
      → hoy `DataManager` crashea en runtime: "no model PrompterAI"
      (Managers/DataManager.swift:8)
- [ ] **B3**. `fetchScripts` ordena por `updatedAt` que nunca se setea → orden
      inestable (Managers/DataManager.swift:50,35). Setear `updatedAt` en create/update.

## 🟠 GRANDES FALLAS DE ARQUITECTURA

- [ ] **F1. Posición única de lectura.** `NeuralFlowEngine.currentIndex` y
      `ScrollEngine.contentOffset` no están sincronizados → tras drag manual o
      error de voz, texto y índice divergen sin recuperación.
      → Fuente de verdad única: posición del texto visible; el reconocimiento
      mapea a esa posición. (TimestampedText + highlight)
- [ ] **F2. La grabación no tiene audio.** El micrófono lo monopoliza el
      reconocimiento de voz (AVAudioEngine en modo `.record`); el video sale mudo.
      → Una sola captura de audio enrutada a SFSpeechAudioBufferRecognitionRequest
      Y a la pista de audio del AVAssetWriter.
- [ ] **F3. El "IA" es un cursor con heurística.** `findMatchIndex` solo busca
      hacia adelante 10 palabras, requiere coincidencia exacta, y `currentIndex`
      solo avanza si `energy > 0.3` (hablar bajito = no avanza).
      → Matching fuzzy (Levenshtein), bidireccional, avance por scroll offset.
- [ ] **F4. Freemium no se aplica.** Marca de agua "Prompter AI Free" es overlay
      de UI, NO está grabada en el video. VideoEngine graba 4K siempre.
      → Watermark quemado en el frame en free; 1080p free / 4K pro.

## 🟡 FALLAS TÁCTICAS (arregladas el 2026-08-10)

- [x] Pausa por puntuación (era código muerto) — `predictPauseNeeded`
- [x] Scroll manual (UIPanGestureRecognizer no hacía nada)
- [x] Video desorientado — rotación + mirror front cam

Pendientes:
- [ ] `energyThreshold = 0.05` fijo, sin calibrar. Resultados parciales duplican
      la misma palabra → falta dedupe / timestamp.
- [ ] La grabación se guarda solo en `Documents`; nunca se guarda en Fotos aunque
      Info.plist ya tiene `NSPhotoLibraryAddUsageDescription`. No hay lista de
      videos ni export.
- [ ] No hay UI para importar guión (el placeholder dice "Toca el botón +"),
      ni settings (font size/color existen en ViewModel sin UI), ni lista de guiones.
- [ ] 4K60 H.264 50Mbps fijo → sobrecalienta/derruba frames en iPhones viejos.
      → Presets adaptativos por dispositivo.
- [ ] `handleTransaction(.failed)` desactiva premium innecesariamente.
- [ ] Reconocimiento de voz hardcodeado a `es-ES` → i18n.
- [ ] Manejo de errores: alertas reales, no `print`.

---

## 🚀 PLAN A 100% (orden de impacto)

**Fase 1 — Compilar y estable**
1. xcdatamodeld + setear `updatedAt` (B2, B3)
2. Manejo de errores real (alertas)

**Fase 2 — Núcleo de valor**
3. F1: fuente de verdad única + highlight
4. F3: matching fuzzy + bidireccional + avance por offset
5. F2: audio en la grabación (captura única)
6. Presets adaptativos por dispositivo

**Fase 3 — Producto**
7. Guardar en Fotos + lista/export de videos
8. Importar guión + editor + settings UI
9. Freemium real: watermark quemado + tiers

**Fase 4 — Polishing**
10. Dedupe de palabras, calibración RMS, telemetría, i18n