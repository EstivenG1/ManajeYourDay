import 'package:flutter/material.dart';

String appText(BuildContext context, String spanish, String english) {
  return Localizations.localeOf(context).languageCode == 'en'
      ? english
      : spanish;
}
