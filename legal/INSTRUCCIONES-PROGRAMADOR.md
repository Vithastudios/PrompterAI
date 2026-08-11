# Instrucciones para el programador web — Páginas legales Prompter AI

Fecha: 11 de agosto de 2026
Proyecto: www.vithastudios.com (Next.js / App Router)

## Qué hay que hacer

Crear dos rutas web en el sitio **www.vithastudios.com** dentro de la sección **`sistemas/erp/`**:

| Ruta | Página | Uso |
|------|--------|-----|
| `https://www.vithastudios.com/sistemas/erp/terms` | Términos de Uso (EULA) | Enlace del paywall de la app Prompter AI |
| `https://www.vithastudios.com/sistemas/erp/privacy` | Política de Privacidad | Enlace del paywall de la app + metadata en App Store Connect |

Ambas rutas deben:
- Responder **200 OK** y ser accesibles públicamente (sin login).
- Estar enlazadas entre sí (privacy enlaza a terms y viceversa).
- Estar incluidas en el `sitemap.ts` y `robots.ts` para que Apple pueda indexarlas si lo desea.

## Archivos a crear (App Router de Next.js)

```
app/sistemas/erp/terms/page.tsx
app/sistemas/erp/privacy/page.tsx
```

## Código base para cada página

Usar el mismo estilo visual del resto del sitio (bg-obsidian, text-gold, text-bone, font-display, font-label).

### app/sistemas/erp/terms/page.tsx

```tsx
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Términos de Uso (EULA) — Vitha Studios',
  description: 'Términos de uso y licencia de software de la aplicación Prompter AI de Vitha Studios, C.A.',
  robots: { index: true, follow: true },
  alternates: { canonical: 'https://www.vithastudios.com/sistemas/erp/terms' },
}

export default function TermsPage() {
  return (
    <>
      <main className="bg-obsidian min-h-screen pt-32 pb-24 px-8">
        <div className="max-w-3xl mx-auto">
          <p className="font-label text-gold mb-4" style={{ fontSize: '1rem', letterSpacing: '0.08em' }}>
            Legal
          </p>
          <h1 className="font-display text-bone mb-12" style={{ fontSize: 'clamp(2rem, 4vw, 3.5rem)' }}>
            Términos de Uso (EULA)
          </h1>

          <div className="space-y-10 text-bone/70 font-light leading-relaxed">

            <section>
              <p className="font-label text-bone/45 mb-3" style={{ fontSize: '0.6rem', letterSpacing: '0.14em' }}>ÚLTIMA ACTUALIZACIÓN — 11 DE AGOSTO DE 2026</p>
              <p>
                <strong className="text-bone/90">Vitha Studios, C.A.</strong> («Vithastudios», «nosotros») es el
                desarrollador y editor de la aplicación móvil para iOS{' '}
                <strong className="text-bone/90">Prompter AI</strong> (teleprompter). Al descargar, instalar o usar la
                aplicación, aceptas los presentes Términos de Uso. Si no estás de acuerdo, no utilices la aplicación.
              </p>
            </section>

            <section>
              <h2 className="font-display text-bone mb-4" style={{ fontSize: '1.4rem' }}>1. Licencia</h2>
              <p>
                Otorgamos una licencia limitada, no exclusiva, no transferible y revocable para usar Prompter AI en
                dispositivos de tu propiedad o bajo tu control, conforme a estas condiciones. Esta licencia no te
                confiere la propiedad del software ni de ninguno de sus componentes.
              </p>
            </section>

            <section>
              <h2 className="font-display text-bone mb-4" style={{ fontSize: '1.4rem' }}>2. Compras integradas (In-App Purchases)</h2>
              <ul className="space-y-2 pl-4 border-l border-gold/20">
                <li>La app se distribuye de forma gratuita con funciones limitadas («plan gratuito»).</li>
                <li>Ofrece una compra integrada de pago único no renovable: «Prompter AI Premium — Compra de por vida».</li>
                <li>Todas las transacciones se procesan a través de la App Store de Apple y están sujetas a sus Condiciones del Servicio.</li>
                <li>La compra de por vida otorga acceso permanente a las funciones premium mientras la app permanezca disponible en la App Store.</li>
                <li>Las compras se restauran mediante el botón «Restaurar Compra» dentro de la app.</li>
              </ul>
            </section>

            <section>
              <h2 className="font-display text-bone mb-4" style={{ fontSize: '1.4rem' }}>3. Uso aceptable</h2>
              <ul className="space-y-2 pl-4 border-l border-gold/20">
                <li>No realizar ingeniería inversa, descompilar ni intentar extraer el código fuente.</li>
                <li>No eludir, desactivar o interferir con las funciones de seguridad o control de licencias.</li>
                <li>No usar la app para violar la privacidad o los derechos de otras personas.</li>
                <li>No grabar contenido que infrinja derechos de terceros o leyes aplicables.</li>
              </ul>
            </section>

            <section>
              <h2 className="font-display text-bone mb-4" style={{ fontSize: '1.4rem' }}>4. Propiedad intelectual</h2>
              <p>
                Todos los derechos, títulos e intereses sobre la aplicación —código, diseño, marca y funcionalidades— son
                propiedad exclusiva de Vitha Studios, C.A. o de sus licenciantes, y están protegidos por las leyes de
                propiedad intelectual.
              </p>
            </section>

            <section>
              <h2 className="font-display text-bone mb-4" style={{ fontSize: '1.4rem' }}>5. Privacidad</h2>
              <p>
                El uso de la aplicación está sujeto a nuestra{' '}
                <a href="/sistemas/erp/privacy" className="text-gold hover:underline">Política de Privacidad</a>,
                que forma parte de estos Términos.
              </p>
            </section>

            <section>
              <h2 className="font-display text-bone mb-4" style={{ fontSize: '1.4rem' }}>6. Sin garantías y limitación de responsabilidad</h2>
              <p>
                La aplicación se proporciona «tal cual» y «según disponibilidad», sin garantías de ningún tipo. En la
                máxima medida permitida por la ley, Vitha Studios, C.A. no será responsable de daños indirectos,
                incidentales, especiales, consecuentes o punitivos, ni de pérdida de datos o beneficios derivados del
                uso o la imposibilidad de uso de la aplicación.
              </p>
            </section>

            <section>
              <h2 className="font-display text-bone mb-4" style={{ fontSize: '1.4rem' }}>7. Modificaciones y terminación</h2>
              <p>
                Podemos actualizar estos Términos o terminar tu acceso a la app en cualquier momento. La versión vigente
                se publicará en esta página.
              </p>
            </section>

            <section>
              <h2 className="font-display text-bone mb-4" style={{ fontSize: '1.4rem' }}>8. Contacto</h2>
              <div className="mt-2 pl-4 border-l border-gold/20 space-y-1">
                <p><strong className="text-bone/90">Vitha Studios, C.A.</strong></p>
                <p>Barquisimeto, Venezuela</p>
                <p><a href="mailto:vithastudios@gmail.com" className="text-gold hover:underline">vithastudios@gmail.com</a></p>
                <p>+58 424 564 2638</p>
                <p><a href="https://www.vithastudios.com" className="text-gold hover:underline">www.vithastudios.com</a></p>
              </div>
            </section>

          </div>
        </div>
      </main>
    </>
  )
}
```

### app/sistemas/erp/privacy/page.tsx

```tsx
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Política de Privacidad — Vitha Studios',
  description: 'Política de privacidad de la aplicación Prompter AI de Vitha Studios, C.A. Cómo gestionamos los datos en la app.',
  robots: { index: true, follow: true },
  alternates: { canonical: 'https://www.vithastudios.com/sistemas/erp/privacy' },
}

export default function PrivacyPage() {
  return (
    <>
      <main className="bg-obsidian min-h-screen pt-32 pb-24 px-8">
        <div className="max-w-3xl mx-auto">
          <p className="font-label text-gold mb-4" style={{ fontSize: '1rem', letterSpacing: '0.08em' }}>
            Legal
          </p>
          <h1 className="font-display text-bone mb-12" style={{ fontSize: 'clamp(2rem, 4vw, 3.5rem)' }}>
            Política de Privacidad
          </h1>

          <div className="space-y-10 text-bone/70 font-light leading-relaxed">

            <section>
              <p className="font-label text-bone/45 mb-3" style={{ fontSize: '0.6rem', letterSpacing: '0.14em' }}>ÚLTIMA ACTUALIZACIÓN — 11 DE AGOSTO DE 2026</p>
              <p>
                Esta política explica cómo <strong className="text-bone/90">Vitha Studios, C.A.</strong> (desarrollador de la
                aplicación <strong className="text-bone/90">Prompter AI</strong>) gestiona la información. Respetamos tu privacidad
                y nos comprometemos a proteger tus datos.
              </p>
            </section>

            <section>
              <h2 className="font-display text-bone mb-4" style={{ fontSize: '1.4rem' }}>1. Datos que procesamos</h2>
              <p className="mb-4">Prompter AI procesa estos datos exclusivamente en tu dispositivo para su funcionamiento:</p>
              <ul className="space-y-2 pl-4 border-l border-gold/20">
                <li>Guiones de texto que escribes o importas para su lectura guiada.</li>
                <li>Audio y vídeo que grabas con tu cámara y micrófono.</li>
                <li>Reconocimiento de voz del sistema, solo para detectar tu voz y mover el texto mientras lees.</li>
              </ul>
            </section>

            <section>
              <h2 className="font-display text-bone mb-4" style={{ fontSize: '1.4rem' }}>2. Almacenamiento</h2>
              <p>
                Tus guiones y vídeos se guardan en el almacenamiento local de tu dispositivo (archivos de la app y, si lo
                eliges, en tu biblioteca de Fotos). No se suben a ningún servidor de Vitha Studios.
              </p>
            </section>

            <section>
              <h2 className="font-display text-bone mb-4" style={{ fontSize: '1.4rem' }}>3. Compras integradas</h2>
              <p>
                Las compras integradas se procesan íntegramente a través de la App Store de Apple. No tenemos acceso ni
                almacenamos los datos de tu método de pago. El estado de tu compra se guarda de forma segura en el
                llavero (Keychain) de tu dispositivo y se verifica con los servidores de Apple.
              </p>
            </section>

            <section>
              <h2 className="font-display text-bone mb-4" style={{ fontSize: '1.4rem' }}>4. Permisos que solicitamos</h2>
              <ul className="space-y-2 pl-4 border-l border-gold/20">
                <li><strong className="text-bone/90">Cámara</strong>: vista previa en vivo y grabación de vídeo.</li>
                <li><strong className="text-bone/90">Micrófono</strong>: captura de audio en tus grabaciones.</li>
                <li><strong className="text-bone/90">Reconocimiento de voz</strong>: avanzar el texto mientras hablas.</li>
                <li><strong className="text-bone/90">Biblioteca de Fotos</strong>: guardar en tu galería los vídeos que exportes.</li>
              </ul>
              <p className="mt-4">
                Puedes denegar o revocar cualquiera de estos permisos desde los Ajustes de tu dispositivo.
              </p>
            </section>

            <section>
              <h2 className="font-display text-bone mb-4" style={{ fontSize: '1.4rem' }}>5. Compartir datos, análisis y publicidad</h2>
              <p>
                No vendemos, alquilamos ni compartimos tus datos personales con terceros. La app no integra servicios de
                análisis ni publicidad de terceros, y no recopilamos información de uso con fines de seguimiento.
              </p>
            </section>

            <section>
              <h2 className="font-display text-bone mb-4" style={{ fontSize: '1.4rem' }}>6. Cambios a esta política</h2>
              <p>
                Podemos actualizar esta política ocasionalmente. La versión vigente se publicará en esta página con su
                fecha de actualización.
              </p>
            </section>

            <section>
              <h2 className="font-display text-bone mb-4" style={{ fontSize: '1.4rem' }}>7. Contacto</h2>
              <div className="mt-2 pl-4 border-l border-gold/20 space-y-1">
                <p><strong className="text-bone/90">Vitha Studios, C.A.</strong></p>
                <p>Barquisimeto, Venezuela</p>
                <p><a href="mailto:vithastudios@gmail.com" className="text-gold hover:underline">vithastudios@gmail.com</a></p>
                <p>+58 424 564 2638</p>
                <p><a href="https://www.vithastudios.com" className="text-gold hover:underline">www.vithastudios.com</a></p>
              </div>
            </section>

          </div>
        </div>
      </main>
    </>
  )
}
```

## Checklist final antes de subir

- [ ] Las dos rutas responden 200 OK sin login.
- [ ] `https://www.vithastudios.com/sistemas/erp/terms` carga la página de Términos.
- [ ] `https://www.vithastudios.com/sistemas/erp/privacy` carga la página de Privacidad.
- [ ] Los enlaces cruzados entre ambas funcionan.
- [ ] Las URLs se añadieron al `sitemap.ts`.
- [ ] Desplegado en producción (Vercel) y verificado en el dominio real con https.

## Nota

La app iOS (Prompter AI) ya apunta a estas dos URLs en su paywall, por lo que **no requiere cambios** una vez publicadas las rutas. Además, la URL de privacidad debe pegarse en App Store Connect como «Política de privacidad».

© Vitha Studios, C.A.
