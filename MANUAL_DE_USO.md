# Manual de Uso — Prompter AI

Teleprompter profesional con IA predictiva para iOS.
Grabación 4K / 1080p, control por voz, guiones locales y modelo freemium.

> Complementa a `MOUNTING_GUIDE.md` (cómo crear el proyecto Xcode).
> Este manual explica **cómo se usa la app** una vez instalada, y cómo está
> organizado el sistema.

---

## 1. Requisitos

- Un **Mac** con Xcode 15+ (para montar y compilar el proyecto).
- Un **iPhone real** con iOS 17+ (el simulador no tiene cámara ni micrófono,
  y el teleprompter no funciona ahí).
- Cuenta de Apple Developer gratuita (suficiente) o de pago.

---

## 2. Primera ejecución (permisos)

Al abrir la app por primera vez aparecerán las solicitudes de permiso.
**Acepta los tres** (son indispensables para la funcionalidad):

1. **Cámara** — para la vista previa en vivo.
2. **Micrófono** — para el control por voz que avanza el texto.
3. **Reconocimiento de voz** — para detectar lo que dices.
4. **Fotos** — para guardar/exportar videos.

Si denegaste alguno, actívalo en Ajustes del sistema > la app.

---

## 3. Pantalla principal

Al abrir, verás la **vista previa de la cámara frontal** con el guion
superpuesto en el centro y un degradado que oscurece los extremos
(por eso el texto se ve "limpio").

**Controles (de abajo hacia arriba):**

| Botón | Acción |
|-------|--------|
| **●** rojo (centro) | Grabar / Detener |
| **Play/Pause** | Reproducir / pausar el scroll del texto |
| **+** | Biblioteca de guiones (importar/listar/editar) |
| **V** | Biblioteca de videos grabados (compartir/exportar/borrar) |
| **A** | Ajustes (tamaño, color, idioma de voz) |
| **PRO** | Pantalla de compra (desbloquear premium) |

La barra blanca en la parte inferior muestra el **progreso** del guion.

---

## 4. Grabar un video

1. Carga un guion (botón **+**).
2. Presiona **●** (rojo). La grabación comienza y el texto empieza a moverse
   automáticamente con tu voz.
3. Habla con naturalidad: el texto avanza/pausa según lo que dices
   (reconocimiento de voz + pausas por puntuación).
4. Presiona **●** de nuevo para **detener**.
5. El video se guarda automáticamente:
   - En la **biblioteca de videos** de la app (botón **V**).
   - Como **mejor esfuerzo** en tu galería de Fotos.

> En el plan **Free** el video sale con **marca de agua** y en 1080p30.
> En **PRO** sale **sin marca** y en la mejor calidad de tu iPhone
> (hasta 4K 60fps en dispositivos compatibles).

### Durante la grabación

- El scroll se controla con tu voz. Si haces **pausa** al hablar, el texto se
  detiene; cuando reanudas, continúa.
- Puedes **arrastrar el texto** con el dedo para reposicionar la lectura.
- La **palabra activa** se resalta en amarillo como referencia.

---

## 5. Guiones

Botón **+** abre la biblioteca de guiones.

- **Crear:** botón **+** (arriba) → título + contenido → Guardar.
- **Cargar:** toca un guion de la lista; se coloca en el teleprompter.
- **Editar:** desliza un guion a la izquierda → "Editar".
- **Borrar:** desliza a la izquierda → "Borrar".
- La posición donde quedaste al leer se **guarda automáticamente** y se
  restaura la próxima vez que cargues ese guion.

---

## 6. Ajustes

Botón **A**:

- **Tamaño de letra** (deslizador).
- **Color del texto** (blanco, amarillo, verde, rojo, cian).
- **Idioma del reconocimiento de voz** (español, inglés, francés, italiano,
  portugués, alemán, etc.).

---

## 7. Videos grabados

Botón **V** muestra la lista de videos:

- **Resolución**, **fecha**, **duración** y **tamaño** de cada uno.
- **Compartir/Exportar:** botón de compartir (guarda en Fotos, envía por
  AirDrop, a archivos, etc.).
- **Borrar:** desliza a la izquierda.

---

## 8. Premium / PRO

El plan PRO (compra única de por vida) desbloquea:

- **Sin marca de agua.**
- **Mayor calidad** (1080p60 / 4K60 según el iPhone).
- Botón **PRO** → pantalla de compra (StoreKit) con restauración de compras.

> Para probar las compras en desarrollo se usa un archivo `.storekit`
> (ver `MOUNTING_GUIDE.md`, sección 6).

---

## 9. Estructura del código

```
PrompterViewModel.swift   Orquesta UI + motores, estado observable
Engines/
  VideoEngine.swift        Captura cámara/mic, escritura .mov (thread-safe)
  ScrollEngine.swift       Scroll continuo del texto (CADisplayLink)
  NeuralFlowEngine.swift   IA de matching por voz (thread-safe) + highlight
  AudioEngine.swift        Reconocimiento de voz + energía/calibración RMS
  VideoPreset.swift        Tiers de calidad por hardware
Managers/
  DataManager.swift        CoreData (guiones)
  VideoSaver.swift         Guarda en Fotos
  VideoLibraryManager.swift  Persistencia de videos grabados + metadata
  Watermarker.swift        Marca de agua (free)
  SubscriptionManager.swift  StoreKit 2 (premium)
UI/
  ViewController.swift     UI UIKit principal
  ScriptLibraryView/EditorView/SettingsView/PaywallView/VideoLibraryView
ContentView.swift          Shell SwiftUI
```

---

## 10. Notas de la auditoría (estado del sistema)

El sistema fue auditado a fondo y **reforzado**:

- **Thread-safety total** en captura/escritura de video y en el motor de IA
  (locks en todas las rutas compartidas entre hilos de audio y principal).
- **Fix de detección de hardware**: los tiers 4K60/1080p60 se deciden por el
  identificador real del dispositivo (`iPhone16,x`, `iPhone17,x`, etc.).
- **Freemium sólido**: marca de agua diagonal + principal; si falla el proceso
  de marca, **no** se regala un video limpio (se bloquea con error).
- **Highlight de palabra activa** + sincronización fina del scroll.
- **Persistencia de posición** por guion y **lista/export** de videos.

**Pendientes** (todos requieren Mac/Xcode):
- Crear el `.xcodeproj` y compilar (ver `MOUNTING_GUIDE.md`).
- Añadir el **App Icon** 1024×1024 (obligatorio para App Store).
- Crear el producto IAP y el `.storekit` de pruebas.

---

## 11. Solución de problemas frecuentes

| Problema | Solución |
|----------|----------|
| El texto no avanza | Verifica permiso de micrófono y voz; habla claro cerca del mic |
| La vista previa queda negra | Permiso de cámara; salir y volver a abrir |
| No guarda en Fotos | Permiso de Fotos (addOnly); el video igual queda en "V" |
| El texto salta al arrastrarlo | Es normal: al arrastrar se reposiciona la lectura |
| Video free sale con marca | Es el plan gratuito; es lo esperado |
