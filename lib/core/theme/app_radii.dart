/// Radios de esquina del sistema de diseño MYD (equivalentes a las
/// clases de Tailwind usadas en el Figma: rounded-xl/2xl/3xl/full).
class AppRadii {
  AppRadii._();

  static const double xl = 12; // chips de cantidad, botones de hora, badges
  static const double xl2 = 16; // módulos, tarjetas KPI, campos de formulario
  static const double xl3 = 24; // tarjeta de balance principal, modal inferior
  static const double full = 999; // avatar, checkbox de tareas, indicador nav

  /// Grosor de borde estándar para elementos interactivos.
  static const double borderWidth = 1.5;
}
