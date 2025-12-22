import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @loginTagline.
  ///
  /// In es, this message translates to:
  /// **'Potencia tu gestión.\nEleva tu negocio.'**
  String get loginTagline;

  /// No description provided for @loginDescription.
  ///
  /// In es, this message translates to:
  /// **'Panel de control integral para la administración eficiente de socios, finanzas y accesos en tiempo real.'**
  String get loginDescription;

  /// No description provided for @loginFeatureReports.
  ///
  /// In es, this message translates to:
  /// **'Reportes en vivo'**
  String get loginFeatureReports;

  /// No description provided for @loginFeatureAccess.
  ///
  /// In es, this message translates to:
  /// **'Control de acceso'**
  String get loginFeatureAccess;

  /// No description provided for @loginTitle.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Bienvenido al Panel de Administración GMS.'**
  String get loginSubtitle;

  /// No description provided for @loginUsernameLabel.
  ///
  /// In es, this message translates to:
  /// **'Usuario o correo electrónico'**
  String get loginUsernameLabel;

  /// No description provided for @loginUsernameHint.
  ///
  /// In es, this message translates to:
  /// **'usuario@diamondgym.com'**
  String get loginUsernameHint;

  /// No description provided for @loginUsernameHelper.
  ///
  /// In es, this message translates to:
  /// **'Introduce tu correo corporativo o ID de usuario.'**
  String get loginUsernameHelper;

  /// No description provided for @loginUsernameRequired.
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu correo o usuario'**
  String get loginUsernameRequired;

  /// No description provided for @loginPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get loginPasswordLabel;

  /// No description provided for @loginForgotPassword.
  ///
  /// In es, this message translates to:
  /// **'¿Olvidaste tu contraseña?'**
  String get loginForgotPassword;

  /// No description provided for @loginPasswordRequired.
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu contraseña'**
  String get loginPasswordRequired;

  /// No description provided for @loginPasswordHelper.
  ///
  /// In es, this message translates to:
  /// **'Mínimo 8 caracteres, al menos un número.'**
  String get loginPasswordHelper;

  /// No description provided for @loginButton.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get loginButton;

  /// No description provided for @loginErrorUnexpected.
  ///
  /// In es, this message translates to:
  /// **'Error inesperado'**
  String get loginErrorUnexpected;

  /// No description provided for @systemStatusLabel.
  ///
  /// In es, this message translates to:
  /// **'Estado del sistema'**
  String get systemStatusLabel;

  /// No description provided for @systemStatusOnline.
  ///
  /// In es, this message translates to:
  /// **'EN LÍNEA'**
  String get systemStatusOnline;

  /// No description provided for @toggleLanguageTooltip.
  ///
  /// In es, this message translates to:
  /// **'Cambiar idioma'**
  String get toggleLanguageTooltip;

  /// No description provided for @toggleThemeTooltip.
  ///
  /// In es, this message translates to:
  /// **'Cambiar tema'**
  String get toggleThemeTooltip;

  /// No description provided for @switchRoleTooltip.
  ///
  /// In es, this message translates to:
  /// **'Cambiar rol (debug)'**
  String get switchRoleTooltip;

  /// No description provided for @logoutTooltip.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get logoutTooltip;

  /// No description provided for @searchMembersHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar miembros, clases...'**
  String get searchMembersHint;

  /// No description provided for @invalidCredentialsError.
  ///
  /// In es, this message translates to:
  /// **'Credenciales inválidas'**
  String get invalidCredentialsError;

  /// No description provided for @userInactiveError.
  ///
  /// In es, this message translates to:
  /// **'La cuenta está inactiva'**
  String get userInactiveError;

  /// No description provided for @tooManyAttemptsError.
  ///
  /// In es, this message translates to:
  /// **'Demasiados intentos fallidos. Intenta de nuevo en {seconds} segundos.'**
  String tooManyAttemptsError(int seconds);

  /// No description provided for @tooManyAttemptsErrorGeneric.
  ///
  /// In es, this message translates to:
  /// **'Demasiados intentos fallidos. Intenta de nuevo más tarde.'**
  String get tooManyAttemptsErrorGeneric;

  /// No description provided for @networkError.
  ///
  /// In es, this message translates to:
  /// **'Error de red. Intenta de nuevo.'**
  String get networkError;

  /// No description provided for @createUserTitle.
  ///
  /// In es, this message translates to:
  /// **'Registrar nuevo usuario'**
  String get createUserTitle;

  /// No description provided for @createUserSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Completa el formulario a continuación para registrar un nuevo miembro del equipo.'**
  String get createUserSubtitle;

  /// No description provided for @fullNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre completo'**
  String get fullNameLabel;

  /// No description provided for @fullNameHint.
  ///
  /// In es, this message translates to:
  /// **'ej. Juan Pérez'**
  String get fullNameHint;

  /// No description provided for @emailLabel.
  ///
  /// In es, this message translates to:
  /// **'Correo electrónico'**
  String get emailLabel;

  /// No description provided for @emailHint.
  ///
  /// In es, this message translates to:
  /// **'ej. juan@diamondgym.com'**
  String get emailHint;

  /// No description provided for @usernameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre de usuario'**
  String get usernameLabel;

  /// No description provided for @corporateEmailLabel.
  ///
  /// In es, this message translates to:
  /// **'Correo corporativo'**
  String get corporateEmailLabel;

  /// No description provided for @systemRoleLabel.
  ///
  /// In es, this message translates to:
  /// **'Rol del sistema'**
  String get systemRoleLabel;

  /// No description provided for @assignedGymLabel.
  ///
  /// In es, this message translates to:
  /// **'Gimnasio asignado'**
  String get assignedGymLabel;

  /// No description provided for @securitySectionTitle.
  ///
  /// In es, this message translates to:
  /// **'Seguridad'**
  String get securitySectionTitle;

  /// No description provided for @passwordLabel.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get passwordLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Confirmar contraseña'**
  String get confirmPasswordLabel;

  /// No description provided for @newPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Nueva contraseña'**
  String get newPasswordLabel;

  /// No description provided for @resetPasswordButton.
  ///
  /// In es, this message translates to:
  /// **'Restablecer contraseña'**
  String get resetPasswordButton;

  /// No description provided for @userActiveLabel.
  ///
  /// In es, this message translates to:
  /// **'Usuario activo'**
  String get userActiveLabel;

  /// No description provided for @userActiveSubtitleOn.
  ///
  /// In es, this message translates to:
  /// **'El usuario puede acceder al sistema'**
  String get userActiveSubtitleOn;

  /// No description provided for @userActiveSubtitleOff.
  ///
  /// In es, this message translates to:
  /// **'El acceso al sistema está deshabilitado'**
  String get userActiveSubtitleOff;

  /// No description provided for @cancelButton.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancelButton;

  /// No description provided for @createUserButton.
  ///
  /// In es, this message translates to:
  /// **'Crear usuario'**
  String get createUserButton;

  /// No description provided for @updateUserButton.
  ///
  /// In es, this message translates to:
  /// **'Actualizar usuario'**
  String get updateUserButton;

  /// No description provided for @saveChangesButton.
  ///
  /// In es, this message translates to:
  /// **'Guardar cambios'**
  String get saveChangesButton;

  /// No description provided for @securityRequirementsTitle.
  ///
  /// In es, this message translates to:
  /// **'Requisitos de seguridad'**
  String get securityRequirementsTitle;

  /// No description provided for @reqMinLength.
  ///
  /// In es, this message translates to:
  /// **'Mínimo 8 caracteres'**
  String get reqMinLength;

  /// No description provided for @reqUppercase.
  ///
  /// In es, this message translates to:
  /// **'Al menos una letra mayúscula'**
  String get reqUppercase;

  /// No description provided for @reqLowercase.
  ///
  /// In es, this message translates to:
  /// **'Al menos una letra minúscula'**
  String get reqLowercase;

  /// No description provided for @reqDigit.
  ///
  /// In es, this message translates to:
  /// **'Al menos un número'**
  String get reqDigit;

  /// No description provided for @reqSpecialChar.
  ///
  /// In es, this message translates to:
  /// **'Un carácter especial'**
  String get reqSpecialChar;

  /// No description provided for @successTitle.
  ///
  /// In es, this message translates to:
  /// **'¡Éxito!'**
  String get successTitle;

  /// No description provided for @successUserCreated.
  ///
  /// In es, this message translates to:
  /// **'Usuario creado correctamente.'**
  String get successUserCreated;

  /// No description provided for @successUserUpdated.
  ///
  /// In es, this message translates to:
  /// **'Usuario actualizado correctamente.'**
  String get successUserUpdated;

  /// No description provided for @errorTitle.
  ///
  /// In es, this message translates to:
  /// **'Error'**
  String get errorTitle;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In es, this message translates to:
  /// **'Las contraseñas no coinciden'**
  String get passwordsDoNotMatch;

  /// No description provided for @passwordRequiredNew.
  ///
  /// In es, this message translates to:
  /// **'La contraseña es requerida para nuevos usuarios'**
  String get passwordRequiredNew;

  /// No description provided for @passwordRequirementsFail.
  ///
  /// In es, this message translates to:
  /// **'La contraseña no cumple con los requisitos de seguridad'**
  String get passwordRequirementsFail;

  /// No description provided for @nameEmailRequired.
  ///
  /// In es, this message translates to:
  /// **'El nombre debe tener al menos 3 caracteres y el email es requerido'**
  String get nameEmailRequired;

  /// No description provided for @userFallbackName.
  ///
  /// In es, this message translates to:
  /// **'Usuario'**
  String get userFallbackName;

  /// No description provided for @createdLabel.
  ///
  /// In es, this message translates to:
  /// **'Creado: {date}'**
  String createdLabel(String date);

  /// No description provided for @noGymsAvailable.
  ///
  /// In es, this message translates to:
  /// **'No hay gimnasios disponibles'**
  String get noGymsAvailable;

  /// No description provided for @selectGymHint.
  ///
  /// In es, this message translates to:
  /// **'Seleccione un gimnasio'**
  String get selectGymHint;

  /// No description provided for @gymsLoadError.
  ///
  /// In es, this message translates to:
  /// **'Error cargando gimnasios'**
  String get gymsLoadError;

  /// No description provided for @okButton.
  ///
  /// In es, this message translates to:
  /// **'OK'**
  String get okButton;

  /// No description provided for @errorWithDetails.
  ///
  /// In es, this message translates to:
  /// **'Error: {details}'**
  String errorWithDetails(String details);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
