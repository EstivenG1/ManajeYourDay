import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Delegado de localización que carga los mensajes desde los archivos ARB.
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  Map<String, String> _localizedStrings = {};

  Future<void> load() async {
    final String languageCode = locale.languageCode;
    final String jsonString =
        await rootBundle.loadString('lib/l10n/app_$languageCode.arb');
    final Map<String, dynamic> jsonMap = json.decode(jsonString);
    _localizedStrings = jsonMap.map((key, value) {
      if (key.startsWith('@')) return MapEntry(key, '');
      return MapEntry(key, value.toString());
    });
  }

  String translate(String key) {
    return _localizedStrings[key] ?? key;
  }

  // Métodos de conveniencia para las claves más usadas
  String get appTitle => translate('appTitle');
  String get appShortTitle => translate('appShortTitle');
  String get appDescription => translate('appDescription');
  String get welcomeTitle => translate('welcomeTitle');
  String get welcomeSubtitle => translate('welcomeSubtitle');
  String get getStarted => translate('getStarted');
  String get login => translate('login');
  String get register => translate('register');
  String get email => translate('email');
  String get password => translate('password');
  String get confirmPassword => translate('confirmPassword');
  String get forgotPassword => translate('forgotPassword');
  String get resetPassword => translate('resetPassword');
  String get sendResetLink => translate('sendResetLink');
  String get continueText => translate('continue');
  String get cancel => translate('cancel');
  String get save => translate('save');
  String get delete => translate('delete');
  String get edit => translate('edit');
  String get create => translate('create');
  String get tasks => translate('tasks');
  String get finances => translate('finances');
  String get goals => translate('goals');
  String get reports => translate('reports');
  String get profile => translate('profile');
  String get settings => translate('settings');
  String get home => translate('home');
  String get noTasks => translate('noTasks');
  String get noMovements => translate('noMovements');
  String get noGoals => translate('noGoals');
  String get addTask => translate('addTask');
  String get addMovement => translate('addMovement');
  String get addGoal => translate('addGoal');
  String get taskTitle => translate('taskTitle');
  String get taskDescription => translate('taskDescription');
  String get dueDate => translate('dueDate');
  String get priority => translate('priority');
  String get status => translate('status');
  String get pending => translate('pending');
  String get completed => translate('completed');
  String get income => translate('income');
  String get expense => translate('expense');
  String get amount => translate('amount');
  String get category => translate('category');
  String get date => translate('date');
  String get balance => translate('balance');
  String get budget => translate('budget');
  String get savingsGoal => translate('savingsGoal');
  String get currency => translate('currency');
  String get language => translate('language');
  String get theme => translate('theme');
  String get darkMode => translate('darkMode');
  String get highContrast => translate('highContrast');
  String get textScale => translate('textScale');
  String get notifications => translate('notifications');
  String get connected => translate('connected');
  String get disconnected => translate('disconnected');
  String get retry => translate('retry');
  String get errorText => translate('error');
  String get success => translate('success');
  String get loading => translate('loading');
  String get noInternet => translate('noInternet');
  String get somethingWentWrong => translate('somethingWentWrong');
  String get accountDeleted => translate('accountDeleted');
  String get deleteAccountConfirm => translate('deleteAccountConfirm');
  String get privacyPolicy => translate('privacyPolicy');
  String get termsOfService => translate('termsOfService');
  String get support => translate('support');
  String get contactEmail => translate('contactEmail');
  String get locationPermission => translate('locationPermission');
  String get cameraPermission => translate('cameraPermission');
  String get notificationPermission => translate('notificationPermission');
  String get openStreetMapAttribution => translate('openStreetMapAttribution');
  String get logout => translate('logout');
  String get changeLanguage => translate('changeLanguage');
  String get changeCurrency => translate('changeCurrency');
  String get exportData => translate('exportData');
  String get importData => translate('importData');
  String get backup => translate('backup');
  String get restore => translate('restore');
  String get version => translate('version');
  String get about => translate('about');
  String get help => translate('help');
  String get legal => translate('legal');
  String get receipt => translate('receipt');
  String get avatar => translate('avatar');
  String get recurring => translate('recurring');
  String get weekly => translate('weekly');
  String get biweekly => translate('biweekly');
  String get monthly => translate('monthly');
  String get daily => translate('daily');
  String get none => translate('none');
  String get overBudget => translate('overBudget');
  String get nearBudgetLimit => translate('nearBudgetLimit');
  String get savingsMilestone => translate('savingsMilestone');
  String get taskReminder => translate('taskReminder');
  String get paymentReminder => translate('paymentReminder');
  String get savingsReminder => translate('savingsReminder');
  String get authenticationRequired => translate('authenticationRequired');
  String get sessionExpired => translate('sessionExpired');
  String get signInAgain => translate('signInAgain');
  String get rateLimited => translate('rateLimited');
  String get unauthorized => translate('unauthorized');
  String get forbidden => translate('forbidden');
  String get notFound => translate('notFound');
  String get serverError => translate('serverError');
  String get networkError => translate('networkError');
  String get tryAgain => translate('tryAgain');
  String get contactSupport => translate('contactSupport');
  String get dataDeleted => translate('dataDeleted');
  String get dataRetention => translate('dataRetention');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['es', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
