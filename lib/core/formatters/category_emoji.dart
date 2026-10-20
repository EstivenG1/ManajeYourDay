String emojiCategoria(String nombre, {String? tipo}) {
  final normalizado = nombre.toLowerCase().trim();
  if (normalizado.contains('aliment') || normalizado.contains('supermerc')) {
    return '🛒';
  }
  if (normalizado.contains('restaur') || normalizado.contains('comida')) {
    return '🍽️';
  }
  if (normalizado.contains('transporte') || normalizado.contains('gasolina')) {
    return '🚗';
  }
  if (normalizado.contains('vivienda') || normalizado.contains('arriendo')) {
    return '🏠';
  }
  if (normalizado.contains('salud') || normalizado.contains('médic')) {
    return '🩺';
  }
  if (normalizado.contains('educac') || normalizado.contains('estudio')) {
    return '📚';
  }
  if (normalizado.contains('entreten') || normalizado.contains('ocio')) {
    return '🎬';
  }
  if (normalizado.contains('servicio') || normalizado.contains('recibo')) {
    return '💡';
  }
  if (normalizado.contains('ropa') || normalizado.contains('compra')) {
    return '🛍️';
  }
  if (normalizado.contains('salario') || normalizado.contains('nómina')) {
    return '💼';
  }
  if (normalizado.contains('freelance')) return '🎨';
  if (normalizado.contains('venta')) return '📦';
  if (normalizado.contains('dividendo') || normalizado.contains('invers')) {
    return '📈';
  }
  if (normalizado.contains('bono')) return '🏆';
  return tipo == 'ingreso' ? '💰' : '💳';
}
