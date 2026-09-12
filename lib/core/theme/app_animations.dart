import 'package:flutter/material.dart';

/// Duraciones, curvas y widgets de animación compartidos del sistema
/// de diseño MYD. Cada pantalla los usa en vez de inventar sus propios
/// tiempos/curvas, para que todo el "movimiento" de la app se sienta
/// igual de premium en todos lados.
class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 200);
  static const Duration base = Duration(milliseconds: 350);
  static const Duration slow = Duration(milliseconds: 600);

  static const Curve entrada = Curves.easeOutCubic;

  /// Delay entre elementos de una lista que entran "escalonados"
  /// (delay-1 a delay-5 en el Figma = 0.05s por elemento).
  static Duration escalon(int indice) => Duration(milliseconds: 50 * indice);
}

/// Envuelve cualquier widget y lo hace entrar con "fadeUp": aparece
/// desde abajo (fade + slide) al montarse. Úsalo en botones, tarjetas
/// y títulos que aparecen al cargar una pantalla.
///
/// Ejemplo con entrada escalonada de una lista:
///   FadeSlideIn(delay: AppMotion.escalon(i), child: MiTarjeta())
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offsetY;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppMotion.base,
    this.offsetY = 16,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _fade = CurvedAnimation(parent: _controller, curve: AppMotion.entrada);
    _slide = Tween<Offset>(
      begin: Offset(0, widget.offsetY / 100),
      end: Offset.zero,
    ).animate(_fade);

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Halo que "respira" lentamente alrededor de un widget (logo en Splash).
class PulseSoft extends StatefulWidget {
  final Widget child;
  const PulseSoft({super.key, required this.child});

  @override
  State<PulseSoft> createState() => _PulseSoftState();
}

class _PulseSoftState extends State<PulseSoft> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final escala = 1.0 + (_controller.value * 0.05);
        return Transform.scale(scale: escala, child: child);
      },
      child: widget.child,
    );
  }
}

/// Anillo decorativo que gira muy lentamente (8s), sutil, usado en
/// Splash y en las pantallas de Auth.
class SpinSlow extends StatefulWidget {
  final Widget child;
  const SpinSlow({super.key, required this.child});

  @override
  State<SpinSlow> createState() => _SpinSlowState();
}

class _SpinSlowState extends State<SpinSlow> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(turns: _controller, child: widget.child);
  }
}
