# Codex Meter

[简体中文](README.md) · [繁體中文](README.zh-Hant.md) · [English](README.en.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · Español

Codex Meter es una utilidad nativa para la barra de menús de macOS que permite consultar rápidamente las ventanas de cuota y la actividad de tokens de una cuenta de ChatGPT/Codex. Lee los datos mediante la interfaz JSON-RPC `app-server` del Codex CLI local, reutiliza la sesión existente y nunca lee ni guarda tokens de acceso.

> Codex Meter es un proyecto independiente de código abierto. No es un producto oficial de OpenAI ni cuenta con su soporte o respaldo.

## Capturas de pantalla

| Chino simplificado · Claro | Inglés · Oscuro |
| --- | --- |
| ![Interfaz clara en chino simplificado](docs/images/overview-zh-Hans-light.png) | ![Interfaz oscura en inglés](docs/images/overview-en-dark.png) |

> Las capturas usan datos de demostración sintéticos y no contienen información de cuentas reales.

## Funciones

- Muestra la cuota semanal restante de Codex en la barra de menús
- Presenta todas las ventanas de cuota, porcentajes restantes y cuentas atrás de restablecimiento
- Resume la actividad de tokens de hoy, los últimos 7 días, el total histórico y un mapa de calor de 90 días
- Usa los datos de ayer cuando todavía no hay actividad de hoy
- Admite actualización manual, intervalos predefinidos y un intervalo personalizado de 1 a 1.440 minutos
- Admite apariencia del sistema, clara y oscura
- Comprueba GitHub Releases mediante Cloudflare al iniciar y cada 6 horas, y ofrece la nueva descarga
- Oculta el correo de la cuenta hasta que se revela de forma explícita
- Conserva la última instantánea correcta si falla una actualización

## Idiomas de la interfaz

El idioma predeterminado es chino simplificado. La aplicación admite actualmente:

- Chino simplificado (`zh-Hans`)
- Chino tradicional (`zh-Hant`)
- Inglés (`en`)
- Japonés (`ja`)
- Coreano (`ko`)
- Español (`es`)

## Descarga

[⬇️ Descargar Codex Meter v1.0.1 (macOS Universal 2)](https://github.com/JTXYH/codex-meter/releases/download/v1.0.1/CodexMeter-1.0.1-macOS.zip)

Esta compilación admite Macs con Apple Silicon e Intel. Descarga y extrae el ZIP y mueve `CodexMeter.app` a la carpeta Aplicaciones. [Consulta las notas de la versión v1.0.1](https://github.com/JTXYH/codex-meter/releases/tag/v1.0.1).

### Si macOS bloquea la aplicación al abrirla por primera vez

La compilación actual usa una firma ad hoc y no está notarizada por Apple. Si al abrirla por primera vez aparece «Apple no puede comprobar si la app contiene software malicioso» o «no se puede verificar el desarrollador», comprueba primero que la aplicación procede de los [GitHub Releases](https://github.com/JTXYH/codex-meter/releases) de este repositorio y utiliza uno de los siguientes métodos.

**Método 1: Abrirla desde Finder**

1. Abre la carpeta Aplicaciones en Finder y localiza `CodexMeter.app`.
2. Haz Control-clic o clic con el botón derecho en la aplicación y selecciona **Abrir**.
3. Vuelve a hacer clic en **Abrir** en el cuadro de confirmación. Después de autorizarla una vez, podrás iniciarla normalmente con un doble clic.

**Método 2: Permitirla desde Ajustes del Sistema**

1. Haz doble clic una vez en `CodexMeter.app` y cierra el aviso de macOS.
2. Abre el menú Apple ** → Ajustes del Sistema → Privacidad y seguridad**.
3. Desplázate hasta Seguridad, busca el mensaje sobre Codex Meter y haz clic en **Abrir igualmente**.
4. Autentícate cuando se te solicite y haz clic en **Abrir**. El botón **Abrir igualmente** suele estar disponible durante aproximadamente una hora después de intentar iniciar la aplicación.

Consulta [Soporte técnico de Apple: Abrir apps de forma segura en el Mac](https://support.apple.com/es-es/102445) para obtener más información. Si macOS indica expresamente que la aplicación «dañará el ordenador» o detecta software malicioso, no ignores el aviso; elimina el archivo actual y vuelve a descargarlo desde el Release oficial.

## Requisitos

- macOS 14 Sonoma o posterior
- [Codex CLI](https://github.com/openai/codex) instalado y con una cuenta de ChatGPT iniciada
- Swift 6 / Xcode 16 o posterior (solo para compilar desde el código fuente)

Codex Meter busca el ejecutable `codex` en `PATH`, `~/.local/bin/codex`, `~/.npm-global/bin/codex`, las ubicaciones habituales de Homebrew y los paquetes de las aplicaciones Codex/ChatGPT.

## Instalación

Después de clonar o descargar el repositorio, ejecuta:

```bash
cd codex-meter
chmod +x scripts/build-app.sh
./scripts/build-app.sh
```

La aplicación se genera en `dist/CodexMeter.app`. Ábrela directamente o muévela a la carpeta Aplicaciones.

Durante el desarrollo también puedes ejecutar:

```bash
swift run CodexMeter
```

## Guía de uso

1. Inicia Codex CLI y comprueba que has iniciado sesión con tu cuenta de ChatGPT.
2. Abre Codex Meter. Su icono y la cuota semanal restante aparecerán en la barra de menús.
3. Haz clic en el elemento de la barra para consultar cuotas, actividad de tokens, mapa de calor y resumen de uso.
4. Usa el botón de actualización de la esquina superior derecha para volver a leer los datos inmediatamente.
5. Haz clic en el correo oculto para mostrarlo temporalmente. Al cerrar el panel vuelve a ocultarse.
6. Abre Ajustes con el engranaje para cambiar la apariencia, el idioma y el intervalo de actualización automática.
7. Cierra la aplicación con el botón de encendido de la esquina inferior derecha.

## Datos y privacidad

- El resumen de la cuenta procede de `account/read`.
- Las ventanas de cuota proceden de `account/rateLimits/read`; el porcentaje representa la parte utilizada de cada ventana.
- La actividad de tokens y el mapa de calor proceden de `account/usage/read`; son estadísticas de actividad, no límites de cuota.
- La aplicación no accede a `auth.json`, no guarda tokens de acceso, no registra respuestas completas del servidor y no sube datos adicionales.
- Los inicios de sesión mediante API Key o Amazon Bedrock pueden no devolver cuotas o actividad de ChatGPT. Usa un inicio de sesión de ChatGPT para ver estas métricas.

## Desarrollo y pruebas

```bash
swift test
swift build -c release
```

El proyecto usa Swift Package Manager y actualmente no tiene dependencias de paquetes de terceros. Verifica que las pruebas y la compilación release terminen correctamente antes de enviar cambios.

## Seguridad

No publiques tokens de acceso, `auth.json`, direcciones de correo completas ni respuestas sin procesar de App Server en un Issue público. Si GitHub Private Vulnerability Reporting está habilitado, informa de forma privada desde **Security → Advisories → Report a vulnerability**.

## Preguntas frecuentes (FAQ)

### ¿Por qué no se admite Claude Code?

![Anthropic rechazó restablecer la cuenta de Claude Code](docs/images/why-claude-code-is-not-supported.png)

## Licencia

Codex Meter se distribuye bajo la [Licencia MIT](LICENSE).
