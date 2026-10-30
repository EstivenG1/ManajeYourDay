/// Configuración de URLs públicas legales y de contacto para tiendas.
class LegalConfig {
  LegalConfig._();

  static final LegalConfig instance = LegalConfig._();

  /// URL pública de la política de privacidad (desplegar en tu sitio web)
  static const String privacyPolicyUrl =
      'https://estiveng1.github.io/ManajeYourDay/legal/privacy-policy.md';

  /// URL pública de los términos y condiciones
  static const String termsOfServiceUrl =
      'https://estiveng1.github.io/ManajeYourDay/legal/terms-of-service.md';

  /// Página de soporte
  static const String supportUrl = 'mailto:manage.your.day.oficial@gmail.com';

  /// Correo de contacto operativo
  static const String contactEmail = 'manage.your.day.oficial@gmail.com';

  /// Nombre oficial de la aplicación
  static const String appName = 'Manage Your Day';

  /// Identificador del paquete Android
  static const String androidPackageId = 'com.manageyourday.app';

  /// URL del sitio web oficial
  static const String websiteUrl =
      'https://estiveng1.github.io/ManajeYourDay/';

  /// Edad mínima de uso
  static const int minimumAge = 13;
}
