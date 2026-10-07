# Gym Tracker para iPhone

Aplicación nativa **SwiftUI para iOS 16 o posterior**, con datos locales. La versión Android está en la carpeta `app/`.

## Actualización del 7 de octubre de 2026

La versión **0.3.1 (build 4)** incorpora el guardado de todos los ejercicios y series, sin checks de completado ni confirmación para omitir pendientes. La casilla opcional «Al fallo» registra el tipo de serie; no condiciona el guardado y no se hereda en series nuevas. También incluye el acabado visual y el mapa muscular que estaban preparados localmente. Mantiene `com.codex.gymtracker` y el formato de datos para actualizar conservando el almacenamiento.

El proyecto y las regresiones están preparados para la compilación y las pruebas con Xcode en macOS. Se conservará el IPA anterior hasta verificar el nuevo archivo. Diagnóstico común: [`../docs/SERIES_SIN_CHECK_2026-10-07.md`](../docs/SERIES_SIN_CHECK_2026-10-07.md).

## Instalador anterior

La revisión **0.3.0 (build 3)** está preparada en el [PR borrador #1](https://github.com/MiguelGValle/gym-tracker-ios/pull/1), sin fusionar en `main`. La ejecución [37472044174](https://github.com/MiguelGValle/gym-tracker-ios/actions/runs/37472044174) validó el commit `fc110adca7004d399678ac0bffb79bc277343d3c`: **47 tests unitarios y 2 de interfaz, 0 fallos**, y archivó la app para iPhone ARM64. El artefacto **GymTracker-iPhone-unsigned** está disponible y necesita firma personal antes de instalarlo. Se mantiene el bundle ID para actualizar conservando el almacenamiento.

## Funciones implementadas en el código

- Pantallas nativas de inicio, entrenamiento, historial, progreso y perfil; tema oscuro naranja.
- Catálogo de 104 ejercicios y seis rutinas iniciales; edición, duplicación y archivado de ejercicios.
- Rutinas editables y carpetas; sesión activa con recuperación del borrador, series, kg/lb, RPE, distancia, superseries y notas.
- Historial con edición, repetición y conversión en rutina; estadísticas y gráficas por fecha y ejercicio.
- Nutrición, perfil corporal, medidas y fotos privadas dentro de la app.
- Copias JSON iOS, lectura de copias Android, importación CSV de Hevy y exportación de sesiones CSV.
- Calculadora de discos y calentamiento.

Las particularidades que necesitan validación adicional están en `VALIDACION.md`. No se anuncia paridad probada con todas las funciones Android: el widget Android no se ha trasladado a una extensión WidgetKit y no hay importación/exportación independiente de medidas en CSV.

## Mapa muscular en el código local

El código local también incorpora un acabado visual actualizado de tarjetas, métricas, botones, rutinas, series, historial, progreso y perfil. Conserva los colores y las acciones originales. La sintaxis y la estructura están verificadas; la revisión visual y la compilación de esta actualización requieren Xcode. El IPA disponible todavía no incluye este acabado. Véase [`../docs/ESTETICA.md`](../docs/ESTETICA.md).

Progreso incorpora un mapa de frente y espalda con los 33 músculos del catálogo, colores relativos a sus series equivalentes y valores desplegables. Respeta el periodo seleccionado y excluye calentamientos. El cambio está aplicado al código local; se verificaron la sintaxis de 20 archivos Swift y la estructura del proyecto, pero quedan pendientes el typecheck y la compilación con Xcode. **El IPA disponible corresponde a la versión anterior y no incluye este mapa; no se ha generado un IPA nuevo.** Detalles en [`../docs/MAPA_MUSCULAR.md`](../docs/MAPA_MUSCULAR.md).

## Cambios del 6 de octubre de 2026

- Los nuevos entrenamientos guardan su fecha, sin medir la duración ni guardar una hora de finalización. Se eliminan el cronómetro, los descansos, sus notificaciones y los campos de duración de las series en toda la interfaz y las estadísticas.
- Al iniciar una rutina o repetir una sesión, cada ejercicio empieza con una sola serie. «Añadir serie» copia los valores de la última, con identidad nueva, sin marcarla completada ni arrastrar tiempos o claves de importación.
- Al tocar peso o repeticiones se selecciona el número completo para sustituirlo escribiendo directamente, también al volver a tocar el mismo campo.
- Los entrenamientos históricos, las rutinas existentes y los borradores recuperados conservan todas sus series y campos originales. Los tiempos antiguos siguen viajando en las copias JSON, los CSV y las importaciones para evitar pérdida de datos; ya no se muestran ni se editan en la app. Al arrancar se cancelan los avisos de descanso de versiones anteriores.
- La fecha del entrenamiento se guarda por separado: cambiarla conserva exactamente los tiempos históricos. Los CSV propios incluyen IDs de sesión, ejercicio y serie y la fecha civil para que dos sesiones con el mismo título/día sigan siendo distintas y reimportarlos no duplique las series. Los CSV Hevy sin esas columnas mantienen su comportamiento e identidad originales.

Estos cambios están aplicados al código local, verificados estructural y sintácticamente en Windows y compilados y probados con Xcode en macOS para el commit indicado arriba. El test UI confirmó la selección completa de peso/repeticiones, el gesto repetido sobre el campo activo y la copia al añadir una serie. La instalación en un iPhone real queda pendiente de firma personal.

## Obtener el IPA desde Windows

1. Abrir la ejecución [37472044174](https://github.com/MiguelGValle/gym-tracker-ios/actions/runs/37472044174) e iniciar sesión en GitHub si lo solicita.
2. Descargar el artefacto **GymTracker-iPhone-unsigned** y extraer `GymTracker-unsigned.ipa`.
3. El archivo contiene una app nativa real, pero **necesita firma antes de instalarse**. El nombre `unsigned` identifica ese estado. No basta con abrirlo en Archivos.

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
