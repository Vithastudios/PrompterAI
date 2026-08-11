# Guia de Montaje en Xcode — Prompter AI

Guia paso a paso para crear el proyecto Xcode y compilar la app.
Requisito: un Mac con Xcode 15+ y una cuenta Apple Developer (gratuita o de pago).

> Este repo **no contiene `.xcodeproj`** (solo codigo fuente y configs).
> Se crea en Xcode siguiendo esta guia.

---

## 1. Crear el proyecto

1. Abrir Xcode → `File > New > Project...`
2. Elegir **iOS > App** → `Next`
3. Configurar:
   | Campo | Valor |
   |---|---|
   | Product Name | `PrompterAI` |
   | Team | Tu cuenta de desarrollador |
   | Organization Identifier | `com.vithastudios` |
   | Bundle Identifier | `com.vithastudios.teleprompter` |
   | Interface | `SwiftUI` |
   | Language | `Swift` |
   | Core Data | **NO** marcar (el modelo se agrega a mano) |
4. Guardar el proyecto **en la raiz del repo** (`C:\PromterAi\PrompterAI` o donde clones).

---

## 2. Reemplazar archivos

Xcode genera plantillas. Hay que reemplazarlas con el codigo real:

- Borrar `ContentView.swift` generado y dejar el `ContentView.swift` del repo.
- Borrar el `PrompterAIApp.swift` generado y dejar el del repo.
- Borrar `Assets.xcassets` generado y reemplazar por `PrompterAI/Assets.xcassets`.

---

## 3. Agregar archivos al target

Arrastrar al proyecto (marcar "Copy items if needed" NO, mejor "Create groups"):

**Compile Sources (20 archivos):**
```
PrompterAIApp.swift
ContentView.swift
PrompterViewModel.swift
Managers/DataManager.swift
Managers/SubscriptionManager.swift
Managers/VideoSaver.swift
Managers/VideoLibraryManager.swift
Managers/Watermarker.swift
Engines/VideoEngine.swift
Engines/ScrollEngine.swift
Engines/NeuralFlowEngine.swift
Engines/AudioEngine.swift
Engines/VideoPreset.swift
UI/ViewController.swift
UI/PaywallView.swift
UI/ScriptLibraryView.swift
UI/ScriptEditorView.swift
UI/SettingsView.swift
UI/VideoLibraryView.swift
```

**Resources:**
- `PrompterAI/Assets.xcassets`
- `PrompterAI/LaunchScreen.storyboard`
- `PrompterAI.xcdatamodeld` (el modelo CoreData)

**Configuracion del target (Build Settings):**
- `INFOPLIST_FILE` → `PrompterAI/Info.plist`
- Privacy manifest → `PrompterAI/PrivacyInfo.xcprivacy`

---

## 4. Configuracion clave

En el target `PrompterAI` → **Build Settings**:

1. **Deployment target** → `iOS 17.0` (obligatorio: `videoRotationAngle` requiere iOS 17).
2. **Signing** → elegir tu Team y `Automatically manage signing`.
3. **Capabilities** → Solo se requiere **In-App Purchase** (StoreKit 2).
   - NO hace falta iCloud, CloudKit, Push ni App Groups (se quitaron para el primer build).
4. **Core Data**: verificar que `PrompterAI.xcdatamodeld` este en la fase
   "Core Data Model" del target, con nombre `PrompterAI`
   (debe coincidir con `NSPersistentContainer(name: "PrompterAI")`).

---

## 5. App Icon (necesario para archivar/subir)

- En `PrompterAI/Assets.xcassets/AppIcon.appiconset` falta la imagen.
- Agregar `AppIcon.png` de **1024×1024 px** en el slot indicado.
  (Para correr en simulador/real con debug no es estrictamente necesario,
  pero si lo es para subir a la App Store.)

---

## 6. In-App Purchase

- El producto `com.vithastudios.premium_lifetime` (non-consumable / lifetime)
  debe existir en **App Store Connect > Apps > (tu app) > In-App Purchases**.
- Para probar en desarrollo, configurar **StoreKit Configuration File**:
  `Product > Scheme > Edit Scheme > Run > Options > StoreKit Configuration` → crear un `.storekit` con ese producto ID.

---

## 7. Probarlo

1. Seleccionar un **iPhone real** (el simulador NO tiene camara ni microfono,
   el teleprompter no funciona ahi).
2. `Cmd+R` para correr.
3. **Primera ejecucion**: pedira permisos de Camara, Microfono y Reconocimiento de voz.
   Aceptar los tres.

---

## Verificacion rapida (que deberia pasar)

- [ ] Compila sin errores (deployment target iOS 17).
- [ ] Al abrir, pide permisos de camara/microfono/voz.
- [ ] Se ve la vista previa de la camara frontal con el texto superpuesto.
- [ ] Al grabar, se crea un `.mov` en `Documents` con video 4K + pista de audio.
- [ ] Hablar hace avanzar/pausar el texto.
