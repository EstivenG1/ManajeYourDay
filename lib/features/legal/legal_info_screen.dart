import 'package:flutter/material.dart';

import '../../core/localization/app_text.dart';
import '../../core/theme/app_theme.dart';

enum LegalDocument { terms, privacy }

class LegalInfoScreen extends StatelessWidget {
  final LegalDocument initialDocument;

  const LegalInfoScreen({
    super.key,
    this.initialDocument = LegalDocument.terms,
  });

  static const _terms = [
    _LegalSection(
      titleEs: '1. Aceptación y alcance',
      titleEn: '1. Acceptance and scope',
      bodyEs: 'Al crear una cuenta o utilizar Maneja Tu Día (MYD), aceptas estas condiciones. Si no estás de acuerdo, no crees una cuenta ni utilices el servicio.',
      bodyEn: 'By creating an account or using Maneja Tu Día (MYD), you agree to these terms. If you do not agree, do not create an account or use the service.',
    ),
    _LegalSection(
      titleEs: '2. Qué ofrece MYD',
      titleEn: '2. What MYD provides',
      bodyEs: 'MYD ofrece herramientas para organizar tareas y registrar movimientos, presupuestos y metas de ahorro, además de resúmenes, reportes y recordatorios. Las funciones disponibles pueden variar según la versión y el plan de tu cuenta. Actualmente la app no procesa pagos ni cambios de suscripción.',
      bodyEn: 'MYD provides tools to organize tasks and record transactions, budgets, and savings goals, as well as summaries, reports, and reminders. Available features may vary by app version and account plan. The app currently does not process payments or subscription changes.',
    ),
    _LegalSection(
      titleEs: '3. Tu cuenta',
      titleEn: '3. Your account',
      bodyEs: 'Debes proporcionar información correcta y mantener la confidencialidad de tus credenciales. Eres responsable de la actividad realizada desde tu cuenta. Si sospechas de un acceso no autorizado o tienes una consulta sobre el servicio, contacta a MYD en manage.your.day.oficial@gmail.com.',
      bodyEn: 'You must provide accurate information and keep your credentials confidential. You are responsible for activity performed through your account. If you suspect unauthorized access or have a question about the service, contact MYD at manage.your.day.oficial@gmail.com.',
    ),
    _LegalSection(
      titleEs: '4. Uso responsable y datos ingresados',
      titleEn: '4. Responsible use and entered data',
      bodyEs: 'Utiliza la app de forma legal y no intentes interferir con su funcionamiento o con las cuentas de otras personas. Tú decides qué información ingresas y eres responsable de que puedas utilizarla en MYD.',
      bodyEn: 'Use the app lawfully and do not attempt to interfere with its operation or other people’s accounts. You decide what information to enter and are responsible for having the right to use it in MYD.',
    ),
    _LegalSection(
      titleEs: '5. Información financiera',
      titleEn: '5. Financial information',
      bodyEs: 'Los saldos, cálculos, recomendaciones y reportes se generan a partir de la información registrada por ti y se ofrecen como herramientas organizativas. MYD no es una entidad financiera ni ofrece asesoría financiera, contable, tributaria o de inversión. Verifica los datos antes de tomar decisiones.',
      bodyEn: 'Balances, calculations, recommendations, and reports are generated from information you enter and are provided as organizational tools. MYD is not a financial institution and does not provide financial, accounting, tax, or investment advice. Verify the information before making decisions.',
    ),
    _LegalSection(
      titleEs: '6. Disponibilidad y servicios de terceros',
      titleEn: '6. Availability and third-party services',
      bodyEs: 'Algunas funciones dependen de conexión a internet y de proveedores externos, por ejemplo para autenticación o almacenamiento. MYD puede actualizar, cambiar o retirar funciones para mantener y mejorar el servicio. Procuraremos informar cambios relevantes dentro de la app cuando corresponda.',
      bodyEn: 'Some features depend on an internet connection and external providers, for example for authentication or storage. MYD may update, change, or discontinue features to maintain and improve the service. Where appropriate, we will try to notify you of significant changes in the app.',
    ),
    _LegalSection(
      titleEs: '7. Exportaciones y recordatorios',
      titleEn: '7. Exports and reminders',
      bodyEs: 'Las exportaciones se generan a petición tuya. Al compartirlas, tú eliges el destino y eres responsable de proteger los archivos compartidos. Los recordatorios dependen de los permisos del dispositivo y de la configuración de notificaciones.',
      bodyEn: 'Exports are generated at your request. When sharing them, you choose the destination and are responsible for protecting shared files. Reminders depend on device permissions and notification settings.',
    ),
    _LegalSection(
      titleEs: '8. Cierre de cuenta',
      titleEn: '8. Account closure',
      bodyEs: 'Puedes solicitar la eliminación desde tu perfil. Cuando la solicitud termina correctamente, MYD elimina la cuenta de acceso, el perfil, la foto de perfil y los registros MYD incluidos en el proceso: tareas, movimientos, presupuestos, metas y aportes de ahorro, movimientos recurrentes, categorías y sugerencias guardadas. Esta acción es irreversible. No elimina tu cuenta de Google ni información que Google u otros proveedores deban conservar según sus propias políticas.',
      bodyEn: 'You can request deletion from your profile. When the request completes successfully, MYD deletes the sign-in account, profile, profile photo, and MYD records covered by the process: tasks, transactions, budgets, savings goals and contributions, recurring transactions, categories, and saved suggestions. This action is irreversible. It does not delete your Google account or information Google or other providers may retain under their own policies.',
    ),
    _LegalSection(
      titleEs: '9. Ley aplicable',
      titleEn: '9. Governing law',
      bodyEs: 'En la medida permitida por la ley, estos términos se rigen por la legislación de la República de Colombia. Las controversias se tramitarán ante las autoridades competentes conforme a las normas aplicables, incluidos los derechos irrenunciables de los consumidores.',
      bodyEn: 'To the extent permitted by law, these terms are governed by the laws of the Republic of Colombia. Disputes will be handled by the competent authorities under applicable rules, including any non-waivable consumer rights.',
    ),
    _LegalSection(
      titleEs: '10. Cambios a estos términos',
      titleEn: '10. Changes to these terms',
      bodyEs: 'Podemos actualizar estos términos cuando cambien la app o sus requisitos. Publicaremos la versión vigente en esta pantalla. Si un cambio requiere tu aceptación, la solicitaremos antes de continuar usando la función afectada.',
      bodyEn: 'We may update these terms when the app or its requirements change. The current version will be published on this screen. If a change requires your consent, we will request it before you continue using the affected feature.',
    ),
  ];

  static const _privacy = [
    _LegalSection(
      titleEs: '1. Información que registras',
      titleEn: '1. Information you provide',
      bodyEs: 'Según las funciones que uses, MYD puede tratar datos de cuenta y perfil como correo, nombre, teléfono, ciudad, país y foto; tareas y fechas; y datos financieros que registres, como ingresos, gastos, categorías, presupuestos, metas de ahorro, aportes y movimientos recurrentes.',
      bodyEn: 'Depending on the features you use, MYD may process account and profile data such as email, name, phone number, city, country, and profile photo; tasks and dates; and financial data you enter, such as income, expenses, categories, budgets, savings goals, contributions, and recurring transactions.',
    ),
    _LegalSection(
      titleEs: '2. Para qué se utiliza',
      titleEn: '2. How information is used',
      bodyEs: 'La información se utiliza para crear y administrar tu cuenta, mostrar y sincronizar tus registros, calcular resúmenes y reportes, aplicar tus preferencias y, cuando corresponda, programar recordatorios y proteger el servicio.',
      bodyEn: 'Information is used to create and manage your account, display and sync your records, calculate summaries and reports, apply your preferences, and, where applicable, schedule reminders and protect the service.',
    ),
    _LegalSection(
      titleEs: '3. Almacenamiento y proveedores',
      titleEn: '3. Storage and providers',
      bodyEs: 'MYD utiliza Supabase para autenticación, base de datos y almacenamiento de la foto de perfil. Si eliges iniciar sesión con Google, la app utiliza la autenticación de Google para crear la sesión. Estos proveedores procesan información necesaria para prestar sus servicios, de acuerdo con sus propias condiciones y políticas.',
      bodyEn: 'MYD uses Supabase for authentication, database, and profile-photo storage. If you choose Google sign-in, the app uses Google authentication to create your session. These providers process information needed to provide their services under their own terms and policies.',
    ),
    _LegalSection(
      titleEs: '4. Preferencias y datos locales',
      titleEn: '4. Preferences and local data',
      bodyEs: 'Preferencias como idioma, moneda, tema y tamaño del texto se guardan en el dispositivo. La app también puede programar notificaciones locales si habilitas esa función y concedes los permisos requeridos.',
      bodyEn: 'Preferences such as language, currency, theme, and text size are stored on your device. The app may also schedule local notifications if you enable the feature and grant the required permissions.',
    ),
    _LegalSection(
      titleEs: '5. Exportar y compartir',
      titleEn: '5. Exporting and sharing',
      bodyEs: 'Cuando solicitas una exportación, la app prepara un archivo con los datos incluidos en esa exportación. Si eliges compartirlo o guardarlo en otra aplicación, el tratamiento posterior dependerá del destino que selecciones.',
      bodyEn: 'When you request an export, the app prepares a file containing the data included in that export. If you choose to share it or save it in another app, subsequent handling depends on the destination you select.',
    ),
    _LegalSection(
      titleEs: '6. Protección y conservación',
      titleEn: '6. Protection and retention',
      bodyEs: 'La información de tu cuenta se conserva mientras la cuenta esté activa. Al completar una solicitud de eliminación, MYD elimina los registros y la foto de perfil cubiertos por el proceso. El plazo de conservación de copias de respaldo y registros técnicos depende de los proveedores y sus políticas; MYD no define aquí un plazo independiente. Se aplican controles de seguridad de los servicios utilizados, pero ningún sistema puede garantizar seguridad absoluta.',
      bodyEn: 'Account information is retained while your account is active. Once an account deletion request completes, MYD deletes the records and profile photo covered by the process. Retention periods for backups and technical logs depend on providers and their policies; MYD does not set a separate period here. Security controls provided by the services in use are applied, but no system can guarantee absolute security.',
    ),
    _LegalSection(
      titleEs: '7. Tus opciones',
      titleEn: '7. Your choices',
      bodyEs: 'Puedes revisar y actualizar varios datos desde tu perfil, cambiar preferencias, desactivar notificaciones y exportar datos disponibles desde las herramientas de exportación. También puedes solicitar la eliminación de la cuenta desde tu perfil. Las preferencias guardadas localmente pueden permanecer en el dispositivo hasta que se borren los datos de la app o esta se desinstale.',
      bodyEn: 'You can review and update many details in your profile, change preferences, disable notifications, and export available data using the export tools. You can also request account deletion from your profile. Preferences stored locally may remain on your device until you clear the app data or uninstall the app.',
    ),
    _LegalSection(
      titleEs: '8. Cambios y consultas',
      titleEn: '8. Changes and questions',
      bodyEs: 'Esta información puede actualizarse si cambian las funciones o el tratamiento de datos. Para consultas o solicitudes relacionadas con tus datos, escribe a MYD en manage.your.day.oficial@gmail.com.',
      bodyEn: 'This information may be updated if features or data practices change. For questions or requests concerning your data, email MYD at manage.your.day.oficial@gmail.com.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialDocument == LegalDocument.terms ? 0 : 1,
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(
          title: Text(
            appText(context, 'Información legal', 'Legal information'),
          ),
          bottom: TabBar(
            indicatorColor: AppColors.gold,
            labelColor: AppColors.goldDeep,
            tabs: [
              Tab(
                text: appText(
                  context,
                  'Términos y condiciones',
                  'Terms and conditions',
                ),
              ),
              Tab(text: appText(context, 'Privacidad', 'Privacy')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _documento(context, _terms),
            _documento(context, _privacy),
          ],
        ),
      ),
    );
  }

  Widget _documento(BuildContext context, List<_LegalSection> sections) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.goldSoftBg,
            borderRadius: BorderRadius.circular(AppRadii.xl2),
            border: Border.all(color: AppColors.goldBorder),
          ),
          child: Text(
            appText(
              context,
              'Versión 1.0 · Actualizado el 16 de octubre de 2026. Lee esta información antes de aceptar; al registrarte, confirmas que comprendes y aceptas los términos y la política de privacidad.',
              'Version 1.0 · Updated October 16, 2026. Please review this information before accepting; by registering, you confirm that you understand and accept the terms and privacy policy.',
            ),
            style: AppTypography.secondary,
          ),
        ),
        const SizedBox(height: 16),
        ...sections.map(
          (section) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.xl2),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appText(context, section.titleEs, section.titleEn),
                    style: AppTypography.itemTitle,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    appText(context, section.bodyEs, section.bodyEn),
                    style: AppTypography.secondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LegalSection {
  final String titleEs;
  final String titleEn;
  final String bodyEs;
  final String bodyEn;

  const _LegalSection({
    required this.titleEs,
    required this.titleEn,
    required this.bodyEs,
    required this.bodyEn,
  });
}
