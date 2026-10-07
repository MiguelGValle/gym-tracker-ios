# Validación iOS

## Actualización 0.3.1/build 4 · 7 de octubre de 2026

Se añade el guardado de todas las series, independientemente del flag `completed` de archivos anteriores. El checkbox opcional de fallo persiste en `setType`; no filtra series ni se copia a nuevas entradas. Las regresiones cubren varias sesiones/ejercicios/series sin marcar y mixtas, tipos de serie, reapertura, backup, CSV, métricas y rollback ante datos inválidos. La prueba UI usa almacenamiento temporal separado del habitual.

El proyecto incluye los archivos locales de acabado visual y mapa muscular. La estructura de Xcode se ha verificado en Windows; la compilación, XCTest y el nuevo IPA requieren la ejecución macOS. El archivo anterior se conserva hasta verificar el resultado nuevo. Los resultados de CI se incorporarán aquí tras terminar.

## Ejecutado en Windows

- Generación determinista del proyecto Xcode y esquema compartido.
- Revisión de referencias a archivos, IDs del proyecto, recursos de icono y archivos plist.
- Comparación del catálogo con los 104 ejercicios originales de Android.
- Análisis sintáctico de 18 archivos Swift con tree-sitter-swift, sin errores detectados. No comprueba tipos ni disponibilidad de APIs de Apple.
- Sintaxis de ambos scripts Bash comprobada con `bash -n`.

La comprobación estructural se ejecuta con `python tools/validate_project.py`. Los resultados no son una compilación Swift ni una prueba de interfaz.

El análisis sintáctico se reproduce instalando `tree-sitter==0.26.0` y `tree-sitter-swift==0.7.3` y ejecutando `python tools/check_swift_syntax.py`. Estas herramientas son solo de desarrollo; no son dependencias de la app.

## Validación macOS de la revisión actual

La ejecución [37472044174](https://github.com/MiguelGValle/gym-tracker-ios/actions/runs/37472044174) del [PR borrador #1](https://github.com/MiguelGValle/gym-tracker-ios/pull/1) pasó para el commit `fc110adca7004d399678ac0bffb79bc277343d3c`, versión 0.3.0 (build 3), el 6 de octubre de 2026.

- Compilación del simulador y **49 XCTest con 0 fallos: 47 unitarios y 2 de interfaz**.
- El test UI de entrada numérica y copia de segunda serie pasó, incluido volver a tocar un campo activo para sustituir su valor.
- Archivo para iPhone ARM64 e IPA sin firmar generados correctamente; artefacto `GymTracker-iPhone-unsigned` (ID 11418620503).
- SHA256 del ZIP de artefacto: `23ffdbf5d2f6269f7d25d2e92a01a5099d5929cdd45b8a8951cce79f966443a8`.
- Resultados `.xcresult` disponibles en el artefacto `iPhone-test-results` (ID 11418415744).
- `main` permanece sin modificar; el PR continúa como borrador. Esta nota actualiza documentación local tras comprobar el CI y no cambia el SHA validado.

## Validación macOS de la revisión anterior

- Tests XCTest de persistencia, backups, CSV, cálculos, fechas y navegación UI: 35 tests, 0 fallos.
- Las medidas y la nutrición guardan días civiles estables al cambiar de zona horaria. Los tests de esa migración se ejecutan sin paralelismo para aislar el cambio temporal de zona.
- Compilación de simulador y archivo de dispositivo ARM64 completados antes de empaquetar el IPA.
- Registro `.xcresult`, IPA y SHA256 incluidos en los artefactos de GitHub Actions.

## Regresiones añadidas el 6 de octubre de 2026

En `GymTrackerTests` se cubren el comienzo con una sola serie al iniciar rutinas o repetir sesiones, la copia de los últimos valores sin identidad/completado/tiempos, el caso de plantilla sin series, la conservación de superseries y la conservación íntegra de borradores y sesiones históricas con sus tiempos legados tras editar, reiniciar y exportar backups. Se verifica que finalizar un entrenamiento nuevo no genere una hora de fin y que editar la fecha conserve exactamente el inicio/fin legados. El roundtrip CSV propio cubre dos sesiones con igual título/día, IDs de serie/ejercicio y reimportación repetida sin duplicados sobre datos ya existentes o almacenamiento vacío. Las pruebas previas de backups Android/Hevy y persistencia permanecen.

En `GymTrackerUITests` se añade una sesión aislada del almacenamiento habitual para comprobar que peso y repeticiones se sustituyen al escribir sin borrar el valor anterior, incluso tras tocar de nuevo el campo activo, y que «Añadir serie» copia esos valores. Estos XCTest y la prueba UI pasaron en el simulador de macOS en la ejecución actual indicada arriba. El tamaño visual con todas las opciones de accesibilidad y la instalación siguen pendientes de confirmar en un iPhone real.

## Pendiente de prueba en iPhone

1. Firmar e instalar con AltStore Classic y cuenta gratuita; renovar sin borrar datos.
2. Iniciar una rutina o repetir una sesión: una serie por ejercicio. Editar peso/repeticiones escribiendo directamente; añadir series y comprobar valores copiados. Enviar app a segundo plano y recuperar todas las series del borrador después de cerrar, sin reloj ni avisos de descanso.
3. Finalizar sesión, editarla, repetirla, crear una rutina y comprobar gráficas.
4. Seleccionar fotos, exportar una copia, restaurarla y comprobar imágenes y registros.
5. Importar una copia real de Android y el CSV personal de Hevy; comprobar fechas, kilos/libras y duplicados.
6. Revisar legibilidad con Dynamic Type, VoiceOver, teclado decimal español y orientación horizontal.

## Diferencias conocidas respecto a Android

- Sin widget de pantalla de inicio en esta versión; añadir WidgetKit requiere otra extensión y otro App ID.
- Sin importación/exportación independiente de medidas corporales CSV; las medidas viajan en JSON.
- No hay una equivalencia visual exacta: usa navegación, formularios, selectores y gráficas nativos de iOS.
- No se ha validado la paridad completa ni el rendimiento de historiales grandes en dispositivo.
