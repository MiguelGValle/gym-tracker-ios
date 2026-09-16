# Gym Tracker para iPhone

Aplicación nativa **SwiftUI para iOS 16 o posterior**, con datos locales. La versión Android sigue en la carpeta `app/` y el APK existente no cambia.

## Estado de la entrega

Se ha preparado el código iOS, el proyecto Xcode y un flujo para comprobarlo y generar un IPA en un Mac de GitHub Actions. **Todavía no se ha ejecutado Xcode ni el simulador desde este equipo Windows. No hay un IPA compilado o firmado en esta entrega.** Las pruebas XCTest incluidas están pendientes de ejecución en macOS. Una revisión estática del proyecto no sustituye esa compilación.

## Funciones implementadas en el código

- Pantallas nativas de inicio, entrenamiento, historial, progreso y perfil; tema oscuro naranja.
- Catálogo de 104 ejercicios y seis rutinas iniciales; edición, duplicación y archivado de ejercicios.
- Rutinas editables y carpetas; sesión activa con recuperación del borrador, series, kg/lb, RPE, duración, distancia, superseries, notas y descanso con notificación local.
- Historial con edición, repetición y conversión en rutina; estadísticas y gráficas por fecha y ejercicio.
- Nutrición, perfil corporal, medidas y fotos privadas dentro de la app.
- Copias JSON iOS, lectura de copias Android, importación CSV de Hevy y exportación de sesiones CSV.
- Calculadora de discos y calentamiento.

Las particularidades que necesitan validación adicional están en `VALIDACION.md`. No se anuncia paridad probada con todas las funciones Android: el widget Android no se ha trasladado a una extensión WidgetKit y no hay importación/exportación independiente de medidas en CSV.

## Obtener el IPA desde Windows

1. Alojar el código de `ios/` y `.github/workflows/ios.yml` en un repositorio privado de GitHub.
2. En **Actions → Build iPhone app → Run workflow**, ejecutar el flujo. La compilación usa un runner macOS, primero ejecuta tests en el simulador y después construye para iPhone ARM64.
3. Si termina correctamente, descargar el artefacto **GymTracker-iPhone-unsigned** y extraer `GymTracker-unsigned.ipa`.
4. El archivo contiene una app nativa real, pero **necesita firma antes de instalarse**. El nombre `unsigned` identifica ese estado. No basta con abrirlo en Archivos.

No hacen falta certificados ni claves de Apple para generar ese IPA sin firmar. GitHub Actions en repositorios privados consume la cuota de la cuenta; revisar la cuota antes de ejecutar. No se configura ningún gasto adicional ni compra en el proyecto.

## Instalar sin suscripción Apple Developer

La vía personal prevista es **AltStore Classic con AltServer en Windows y tu propia cuenta de Apple**:

1. Seguir la [guía oficial de Windows](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows) para instalar AltServer y AltStore Classic en el iPhone. La guía indica los componentes Apple necesarios y el emparejamiento del teléfono.
2. Guardar el IPA generado en Archivos del iPhone.
3. Con AltServer disponible y el teléfono conectado según la guía, abrir **AltStore → My Apps → +** y elegir el IPA.
4. AltStore firma la app con tu cuenta e instala Gym Tracker. Introducir las credenciales únicamente en el software de instalación; nunca en el repositorio ni en un chat.
5. Con una cuenta gratuita, la firma **caduca a los siete días**. Renovarla desde AltStore; no desinstalar Gym Tracker para renovarla, porque se borrarían sus datos. Exportar copias periódicas desde Perfil.

Esta es AltStore **Classic**, la versión que permite cargar un IPA propio. No es el marketplace AltStore PAL. Hay límites de aplicaciones activas y App IDs en cuentas gratuitas. Consulta el [funcionamiento y renovación](https://faq.altstore.io/altstore-classic/your-altstore) y los [límites de apps](https://faq.altstore.io/altstore-classic/activating-apps) en la documentación oficial. La instalación con este iPhone aún no se ha probado.

## Compilar en un Mac

Abrir `GymTracker.xcodeproj` con Xcode o ejecutar:

```bash
bash tools/test_ios.sh
bash tools/build_unsigned.sh
```

Los scripts regeneran el proyecto a partir de los archivos Swift. La generación solo requiere Python 3 y no usa CocoaPods ni paquetes externos. El icono ya está incluido; `tools/generate_assets.py` permite regenerarlo con Pillow a partir de la geometría del icono Android.

Para instalación directa con Xcode: seleccionar el equipo personal en **Signing & Capabilities**, conectar el iPhone y ejecutar la app. Para distribución mediante TestFlight se requiere la correspondiente membresía de Apple y la configuración de firma; el flujo incluido no publica en TestFlight ni en App Store.

## Datos y privacidad

El código no incorpora analítica ni sincronización remota. Los datos se escriben en Application Support con reemplazo atómico y una copia anterior. Las fotos seleccionadas se copian en formato JPEG dentro del almacenamiento y de los backups, con un límite total de 20 MB. Las copias exportadas contienen datos y fotos personales; guárdalas donde decidas.

La copia nativa iOS usa un formato distinto al de Android. iOS puede leer el formato Android existente; **no se garantiza restaurar una copia iOS en la app Android actual**. Las fechas Android sin zona se interpretan en la zona del iPhone. El CSV de Gym Tracker es para portabilidad, no se anuncia como formato admitido por Hevy para volver a importar.
