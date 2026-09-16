# Validación iOS

## Ejecutado en Windows

- Generación determinista del proyecto Xcode y esquema compartido.
- Revisión de referencias a archivos, IDs del proyecto, recursos de icono y archivos plist.
- Comparación del catálogo con los 104 ejercicios originales de Android.
- Análisis sintáctico de 17 archivos Swift con tree-sitter-swift, sin errores detectados. No comprueba tipos ni disponibilidad de APIs de Apple.
- Sintaxis de ambos scripts Bash comprobada con `bash -n`.

La comprobación estructural se ejecuta con `python tools/validate_project.py`. Los resultados no son una compilación Swift ni una prueba de interfaz.

El análisis sintáctico se reproduce instalando `tree-sitter==0.26.0` y `tree-sitter-swift==0.7.3` y ejecutando `python tools/check_swift_syntax.py`. Estas herramientas son solo de desarrollo; no son dependencias de la app.

## Preparado, pendiente de macOS

- Tests XCTest de persistencia, backups, CSV, cálculos y fechas.
- Las medidas y la nutrición guardan días civiles estables al cambiar de zona horaria. Los tests de esa migración se ejecutan sin paralelismo para aislar el cambio temporal de zona.
- Prueba UI de navegación por los cinco destinos principales.
- Compilación de simulador y archivo de dispositivo ARM64 antes de empaquetar el IPA.
- Registro `.xcresult` y SHA256 del IPA como artefactos de GitHub Actions.

## Pendiente de prueba en iPhone

1. Firmar e instalar con AltStore Classic y cuenta gratuita; renovar sin borrar datos.
2. Iniciar una sesión, marcar series, enviar app a segundo plano, esperar aviso de descanso y recuperar borrador después de cerrar.
3. Finalizar sesión, editarla, repetirla, crear una rutina y comprobar gráficas.
4. Seleccionar fotos, exportar una copia, restaurarla y comprobar imágenes y registros.
5. Importar una copia real de Android y el CSV personal de Hevy; comprobar fechas, kilos/libras y duplicados.
6. Revisar legibilidad con Dynamic Type, VoiceOver, teclado decimal español y orientación horizontal.

## Diferencias conocidas respecto a Android

- Sin widget de pantalla de inicio en esta versión; añadir WidgetKit requiere otra extensión y otro App ID.
- Sin importación/exportación independiente de medidas corporales CSV; las medidas viajan en JSON.
- No hay una equivalencia visual exacta: usa navegación, formularios, selectores y gráficas nativos de iOS.
- No se ha validado la paridad completa ni el rendimiento de historiales grandes en dispositivo.
