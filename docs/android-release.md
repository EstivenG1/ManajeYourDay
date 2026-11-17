# Publicar el APK de MYD para Android

El flujo de publicación compila un APK firmado y un AAB al enviar un tag `v*`.
Adjunta ambos archivos a una versión de GitHub Releases. La página
[Descargar MYD](https://estiveng1.github.io/ManajeYourDay/descargar/) encuentra
el asset `MYD.apk` más reciente y habilita su descarga automáticamente.

## 1. Crear y respaldar la clave de firma

Usa una clave permanente para todas las versiones. Si se pierde o se cambia,
Android no podrá instalar futuras versiones encima de las ya instaladas. Guarda
copias seguras fuera del repositorio y en un gestor de contraseñas; nunca
compartas la clave ni sus contraseñas en chats, issues o commits.

En PowerShell, genera la clave en tu carpeta de usuario. `keytool` solicitará
las contraseñas de forma interactiva:

```powershell
$keystorePath = Join-Path $env:USERPROFILE "myd-upload-key.jks"
keytool -genkeypair -v -keystore $keystorePath -keyalg RSA -keysize 2048 -validity 10000 -alias myd-upload
```

Respalda el archivo JKS de forma segura antes de continuar. No lo guardes dentro
del repositorio.

## 2. Configurar GitHub Actions

En **Settings > Secrets and variables > Actions > Secrets**, crea estos secretos
del repositorio:

| Secret | Valor |
| --- | --- |
| `ANDROID_KEYSTORE_PASSWORD` | Contraseña del keystore |
| `ANDROID_KEY_ALIAS` | `myd-upload` |
| `ANDROID_KEY_PASSWORD` | Contraseña de la clave |
| `ANDROID_KEYSTORE_BASE64` | El keystore codificado en Base64 |

Para copiar el Base64 al portapapeles sin imprimirlo en la terminal:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes($keystorePath)) | Set-Clipboard
```

Pega el contenido directamente en el secreto de GitHub. No lo envíes por chat ni
lo agregues al repositorio.

En **Settings > Secrets and variables > Actions > Variables**, crea la variable
de repositorio `ANDROID_RELEASE_ENABLED` con valor `true`.

## 3. Publicar una versión

Elige un tag nuevo. Comprueba primero que no exista y luego envíalo:

```powershell
git tag v1.3.0-beta.3
git push origin v1.3.0-beta.3
```

El ejemplo corresponde a la siguiente versión Beta disponible al escribir esta
guía; usa otro tag si ya existe o si vas a publicar una versión diferente.
GitHub Actions usa el tag como versión, firma el APK y el AAB y los adjunta a
GitHub Releases. Los tags con guion, como `-beta.3`, se publican como
pre-lanzamientos.

## Descarga e instalación

La página de descarga revisa las versiones publicadas y solo activa el botón si
encuentra `MYD.apk`. Android puede pedir permiso para instalar una aplicación
descargada desde el navegador. Las actualizaciones futuras deben estar firmadas
con la misma clave; el usuario descarga e instala el APK más reciente.

No subas `android/key.properties`, keystores, contraseñas ni APKs generados al
repositorio.
