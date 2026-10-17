import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../settings/app_settings.dart';

String get sufijoMonedaEntrada => AppSettings.instance.currency;

String get _separadorMiles =>
    const {'USD', 'MXN', 'PEN'}.contains(AppSettings.instance.currency)
    ? ','
    : '.';

String get _separadorDecimal => _separadorMiles == ',' ? '.' : ',';

String formatearMontoEntrada(String value) =>
    _agruparMonto(_normalizar(value));

String formatearMontoParaCampo(num value) {
  final fijo = value.toStringAsFixed(2);
  final partes = fijo.split('.');
  final decimales = partes.last.replaceFirst(RegExp(r'0+$'), '');
  final normalizado = decimales.isEmpty
      ? partes.first
      : '${partes.first}.$decimales';
  return _agruparMonto(normalizado);
}

String _agruparMonto(String normalizado) {
  final partes = normalizado.split('.');
  final digitosEnteros = partes.first;
  final entero = digitosEnteros.isEmpty
      ? ''
      : digitosEnteros.replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => _separadorMiles,
        );

  if (partes.length == 1) return entero;
  return '$entero$_separadorDecimal${partes.last}';
}

double? parseMontoEntrada(String value) {
  final normalizado = _normalizar(value);
  if (normalizado.isEmpty || normalizado == '.') return null;
  return double.tryParse(normalizado);
}

String _normalizar(String value) {
  final buffer = StringBuffer();
  var separadorDecimalAgregado = false;
  var digitosDecimales = 0;
  final separadorMiles = _separadorMiles;
  final separadorDecimal = _separadorDecimal;

  for (final char in value.split('')) {
    if (RegExp(r'\d').hasMatch(char)) {
      if (!separadorDecimalAgregado) {
        buffer.write(char);
      } else if (digitosDecimales < 2) {
        digitosDecimales++;
        buffer.write(char);
      }
    } else if (char == separadorDecimal && !separadorDecimalAgregado) {
      separadorDecimalAgregado = true;
      buffer.write('.');
    } else if (char == separadorMiles) {
      continue;
    }
  }

  final result = buffer.toString();
  final decimalIndex = result.indexOf('.');
  final enteros = decimalIndex == -1
      ? result
      : result.substring(0, decimalIndex);
  final decimales = decimalIndex == -1
      ? ''
      : result.substring(decimalIndex + 1);
  final enterosSinCeros = enteros.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  if (decimalIndex == -1) return enterosSinCeros;
  return '$enterosSinCeros.$decimales';
}

class MoneyTextFormField extends StatelessWidget {
  final TextEditingController controller;
  final InputDecoration decoration;
  final FormFieldValidator<String>? validator;
  final TextStyle? style;
  final bool autofocus;

  const MoneyTextFormField({
    super.key,
    required this.controller,
    this.decoration = const InputDecoration(),
    this.validator,
    this.style,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: const [MoneyInputFormatter()],
      decoration: decoration.copyWith(
        suffixText: decoration.suffixText ?? sufijoMonedaEntrada,
      ),
      validator: validator,
      style: style,
    );
  }
}

class MoneyInputFormatter extends TextInputFormatter {
  const MoneyInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = formatearMontoEntrada(newValue.text);
    final caretOffset = newValue.selection.isValid
        ? newValue.selection.extentOffset.clamp(0, newValue.text.length)
        : newValue.text.length;
    final prefix = newValue.text.substring(0, caretOffset);
    final semanticPosition = _semanticLength(prefix);
    final formattedCaret = _offsetForSemanticPosition(
      formatted,
      semanticPosition,
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formattedCaret),
      composing: TextRange.empty,
    );
  }

  int _semanticLength(String value) =>
      value
          .split('')
          .where(
            (char) => RegExp(r'\d').hasMatch(char) || char == _separadorDecimal,
          )
          .length;

  int _offsetForSemanticPosition(String value, int position) {
    if (position == 0) return 0;
    var semanticLength = 0;
    for (var index = 0; index < value.length; index++) {
      if (RegExp(r'\d').hasMatch(value[index]) ||
          value[index] == _separadorDecimal) {
        semanticLength++;
      }
      if (semanticLength == position) return index + 1;
    }
    return value.length;
  }
}
