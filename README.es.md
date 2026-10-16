# Codex Meter 2.0

[简体中文](README.md) · [繁體中文](README.zh-Hant.md) · [English](README.en.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · Español

<img src="Resources/AppIcon.png" alt="Icono de Codex Meter" width="96">

Aplicación nativa para la barra de menús de macOS que muestra la cuota de tu cuenta de Codex, el uso entre dispositivos y los tokens en tiempo real de este Mac. Haz clic en la barra de menús para abrir el panel.

Codex Meter es un proyecto independiente de código abierto, sin afiliación con OpenAI.

[Descargar v2.0.0](https://github.com/JTXYH/codex-meter/releases/download/v2.0.0/CodexMeter-2.0.0-macOS.zip) · [Notas de la versión](https://github.com/JTXYH/codex-meter/releases/tag/v2.0.0) · [Informar de un problema](https://github.com/JTXYH/codex-meter/issues)

## Capturas

Las capturas usan datos de demostración.

| A · Panel ligero | B · Panel de datos |
| --- | --- |
| ![Panel ligero](docs/images/panel-light.png) | ![Panel de datos](docs/images/panel-data.png) |

![Centro de ajustes compartido](docs/images/settings.png)

## Funciones

- **Dos temas:** un anillo morado en el panel ligero y una escala horizontal verde en el panel de datos. Los ajustes adoptan el color de acento del tema. Ambos admiten apariencia del sistema, clara y oscura.
- **Cuota y restablecimiento:** la barra de menús prioriza la cuota restante de 5 horas y usa la semanal cuando es la única disponible. El panel muestra los periodos y las horas de restablecimiento que devuelve la cuenta. Puedes personalizar los mensajes de uso disponible, cuota baja y espera de restablecimiento.
- **Detalle de hoy:** lectura incremental de contadores locales cada 5 segundos, con entrada, salida, entrada en caché y detalle por modelo.
- **Historial de la cuenta:** totales diarios, semanales, mensuales y anuales de tokens desde los endpoints oficiales de la cuenta, incluidos otros dispositivos y tareas en la nube. Muestra nombres de modelos, etiquetas Fast y porcentajes de uso cuando los datos lo permiten.
- **Actividad:** ayer, los últimos 7 días, el mes actual, un mapa de calor de 120 días y los tokens acumulados, rachas y tarea individual más larga que proporciona la cuenta.
- **Tarjetas de restablecimiento:** cantidad disponible y fecha y hora de caducidad de cada tarjeta, obtenidas del endpoint oficial y ordenadas por caducidad. Son de solo lectura; la aplicación no canjea tarjetas ni restablece cuotas.
- **Saldo de Credits:** saldo para uso adicional, con la conversión indicada más abajo.
- **Ajustes compartidos:** visibilidad y orden de tarjetas mediante arrastre, tamaño del anillo de la barra de menús, tamaño de letra global o por tarjeta, frecuencia de actualización, inicio, idioma y limpieza de datos locales.
- **Actualizaciones y privacidad:** actualizaciones dentro de la aplicación con Sparkle. El correo se oculta por defecto; haz clic para mostrarlo temporalmente. Al cerrar el panel vuelve a ocultarse.

La interfaz admite chino simplificado, chino tradicional, inglés, japonés, coreano y español. En el primer inicio sigue el idioma preferido del sistema y usa inglés si no hay coincidencia.

## Instalación y uso

Requiere macOS 14 Sonoma o posterior. La compilación Universal es compatible con Apple Silicon e Intel. Instala primero la [aplicación de escritorio o CLI de Codex](https://github.com/openai/codex) e inicia sesión con una cuenta de ChatGPT.

1. Descarga el ZIP de [GitHub Releases](https://github.com/JTXYH/codex-meter/releases/latest), descomprímelo y mueve `CodexMeter.app` a Aplicaciones.
2. Abre Codex Meter y haz clic en su anillo de cuota en la barra de menús.
3. El botón superior derecho actualiza los datos; el engranaje inferior izquierdo abre los ajustes; el botón de encendido inferior derecho cierra la aplicación.
4. Elige inicio manual, al iniciar sesión o junto con Codex. Las dos últimas opciones son excluyentes. Seguir a Codex requiere la aplicación empaquetada y puede necesitar permiso para su ayudante en segundo plano en Ítems de inicio y extensiones de macOS.

El script de compilación usa firma ad-hoc por defecto, lo que no implica notarización de Apple. Si macOS bloquea el primer inicio, comprueba el origen y el archivo de verificación SHA-256 de la versión antes de usar Abrir igualmente en Ajustes del Sistema → Privacidad y seguridad.

Las versiones de distribución permiten buscar actualizaciones en Acerca de y actualizaciones y las comprueban automáticamente cada 6 horas. Sparkle verifica los paquetes antes de instalarlos. Las compilaciones de desarrollo no realizan comprobaciones automáticas.

## Origen y significado de los datos

| Datos | Origen y criterio |
| --- | --- |
| Cuenta, cuota y restablecimientos | `app-server` oficial del CLI local de Codex: `account/read` y `account/rateLimits/read`. |
| Tokens históricos, mapa de calor y resumen | Estadísticas de la cuenta de `account/usage/read`. Las fechas sin datos quedan sin datos; no se completan con registros locales. |
| Modelos históricos y porcentajes | Endpoint oficial de la cuenta `daily-token-usage-breakdown`. Cada porcentaje es la suma de los pesos `credits` del modelo dividida por la suma de todos los pesos de la misma respuesta. No representa tokens ni costes en dólares. Si faltan pesos, se muestran los modelos sin porcentaje. |
| Tokens y modelos de hoy | Eventos de contadores del día en los registros locales de sesiones y archivos de Codex. Solo cubren este Mac. |
| Tarjetas de restablecimiento | `rateLimitResetCredits` de `account/rateLimits/read`. La cantidad usa `availableCount`; las caducidades proceden del detalle de tarjetas disponibles. Si falta el detalle, se conserva la cantidad oficial y se muestra un aviso. |
| Saldo de Credits | Credits oficiales convertidos para su visualización a una tasa fija de `1 Credit = US$0.04`. Es independiente del coste de API calculado por tokens. |

Hoy y el historial comparten **límites de día en UTC** para evitar que el «hoy» local se solape con el «ayer» de la cuenta. Las semanas van de lunes a domingo en UTC. Los restablecimientos y las caducidades se muestran en la zona horaria actual del Mac. Los totales históricos, incluido cualquier dato de hoy, solo usan la respuesta de la cuenta; nunca se les suman los contadores locales en tiempo real.

Se han eliminado el cálculo de costes de API y sus ajustes. Las sesiones con API key o Amazon Bedrock pueden no ofrecer cuotas de ChatGPT, historial de modelos o tarjetas. Las respuestas también pueden llegar con retraso o sin algunos campos. Si una actualización falla, se conservan los últimos datos válidos; si falla la primera carga, se ofrece reintentar.

## Almacenamiento local y privacidad

Los ajustes, contadores locales y posiciones de lectura se guardan en:

```text
~/Library/Application Support/CodexMeter/meter.sqlite
```

SQLite utiliza WAL y transacciones. Las cuotas, el historial y los resultados de modelos solo se mantienen en memoria. La aplicación extrae contadores de uso de los registros sin guardar ni subir el texto de las conversaciones.

Las peticiones de modelos usan la sesión existente de ChatGPT en `$CODEX_HOME/auth.json` (por defecto, `~/.codex/auth.json`). Tras comprobar la identidad de la cuenta, se envían a `chatgpt.com`. Los tokens de acceso no se guardan en la base de datos ni en los registros de la aplicación.

En Ajustes → Datos locales puedes eliminar estadísticas guardadas por antigüedad o borrarlas todas. Se conservan los registros originales de Codex, las estadísticas de la cuenta y los ajustes. El límite de limpieza persiste para que los eventos antiguos no vuelvan a importarse al reiniciar.

No adjuntes tokens de acceso, `auth.json`, correos completos ni respuestas originales de la cuenta a incidencias públicas.

## Compilar desde el código fuente

Requiere Swift 6 (Xcode 16 o posterior).

```bash
git clone https://github.com/JTXYH/codex-meter.git
cd codex-meter
./scripts/build-app.sh release
```

El resultado se guarda en `dist/CodexMeter.app`. Cada compilación elimina primero los artefactos anteriores del directorio `dist/` del proyecto. El CLI seleccionado manualmente tiene prioridad. La búsqueda automática prefiere el incluido en la aplicación de escritorio Codex/ChatGPT y después revisa las rutas de instalación habituales.

```bash
swift run CodexMeter
swift test
```

Consulta la [guía de publicación](docs/releasing.md) para empaquetar y firmar. `master` contiene la versión 2.0. El `master` publicado antes de esta versión se conserva en la [rama V1.0](https://github.com/JTXYH/codex-meter/tree/V1.0).

## Licencia

[MIT License](LICENSE)
