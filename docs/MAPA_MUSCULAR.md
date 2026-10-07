# Mapa muscular

La pantalla de Progreso muestra el cuerpo de frente y de espalda, con regiones para los 33 músculos del catálogo. Android respeta los filtros existentes de periodo y ejercicio; iOS respeta el periodo seleccionado.

El trabajo se expresa en **series equivalentes**: cada serie efectiva aporta el porcentaje de participación definido en el ejercicio. Por ejemplo, dos series con un 50 % para un músculo suman una serie equivalente. Se excluyen calentamientos; un ejercicio sin porcentajes conocidos no aporta datos al mapa.

El color es relativo al músculo del catálogo más trabajado en la selección: azul `#477ED1` para menos trabajo, verde azulado `#30BCAA` en el punto medio y naranja `#FF7A3D` para más trabajo. El gris `#48505E` indica cero. La escala es comparativa, no una medida de recuperación ni un objetivo de entrenamiento.

Ambos lados del cuerpo comparten valores porque las series no registran trabajo izquierdo y derecho por separado. Glúteo medio y abductores comparten la región lateral de la cadera; su color usa la media de ambos valores, incluyendo cero si uno no se ha trabajado. Así, una región no recibe más intensidad solo por representar varios músculos.

El desplegable muestra las series de los 33 músculos del catálogo. La distribución muscular original conserva los nombres personalizados; las regiones anatómicas usan únicamente los nombres del catálogo. La geometría compartida está en `docs/muscle-map.json` y se genera mediante `tools/generate_muscle_map.py`.

## Validación de esta actualización

- Android: `testDebugUnitTest assembleDebug assembleDebugAndroidTest lintDebug` terminó correctamente. Se aprobaron 66 tests unitarios, incluidos 10 del cálculo muscular. Lint tiene cero errores y 25 avisos. La prueba real de interfaz en el emulador comprobó ambas vistas, valores accesibles, desplegar y ocultar la lista, filtros de periodo y ejercicio y el estado gris sin series. Evidencias en `outputs/qa/muscle-map/`. Compilar el APK de pruebas instrumentadas no equivale a ejecutarlas.
- iOS: se verificaron la sintaxis de 20 archivos Swift y la estructura del proyecto. El mapa aún no se ha comprobado mediante typecheck ni compilado con Xcode, y no se ha generado un IPA nuevo.

El APK Android de esta actualización incorpora el mapa. El IPA disponible corresponde a la versión anterior y **no incluye el mapa muscular**.
