// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get loginTagline => 'Potencia tu gestión.\nEleva tu negocio.';

  @override
  String get loginDescription =>
      'Panel de control integral para la administración eficiente de socios, finanzas y accesos en tiempo real.';

  @override
  String get loginFeatureReports => 'Reportes en vivo';

  @override
  String get loginFeatureAccess => 'Control de acceso';

  @override
  String get loginTitle => 'Iniciar sesión';

  @override
  String get loginSubtitle => 'Bienvenido al Panel de Administración GMS.';

  @override
  String get loginUsernameLabel => 'Usuario o correo electrónico';

  @override
  String get loginUsernameHint => 'usuario@diamondgym.com';

  @override
  String get loginUsernameHelper =>
      'Introduce tu correo corporativo o ID de usuario.';

  @override
  String get loginUsernameRequired => 'Ingresa tu correo o usuario';

  @override
  String get loginPasswordLabel => 'Contraseña';

  @override
  String get loginForgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get loginPasswordRequired => 'Ingresa tu contraseña';

  @override
  String get loginPasswordHelper => 'Mínimo 8 caracteres, al menos un número.';

  @override
  String get loginButton => 'Iniciar sesión';

  @override
  String get loginErrorUnexpected => 'Error inesperado';

  @override
  String get systemStatusLabel => 'Estado del sistema';

  @override
  String get systemStatusOnline => 'EN LÍNEA';

  @override
  String get toggleLanguageTooltip => 'Cambiar idioma';

  @override
  String get toggleThemeTooltip => 'Cambiar tema';

  @override
  String get switchRoleTooltip => 'Cambiar rol (debug)';

  @override
  String get logoutTooltip => 'Cerrar sesión';

  @override
  String get searchMembersHint => 'Buscar miembros, clases...';

  @override
  String get invalidCredentialsError => 'Credenciales inválidas';

  @override
  String get userInactiveError => 'La cuenta está inactiva';

  @override
  String tooManyAttemptsError(int seconds) {
    return 'Demasiados intentos fallidos. Intenta de nuevo en $seconds segundos.';
  }

  @override
  String get tooManyAttemptsErrorGeneric =>
      'Demasiados intentos fallidos. Intenta de nuevo más tarde.';

  @override
  String get networkError => 'Error de red. Intenta de nuevo.';

  @override
  String get createUserTitle => 'Registrar nuevo usuario';

  @override
  String get createUserSubtitle =>
      'Completa el formulario a continuación para registrar un nuevo miembro del equipo.';

  @override
  String get fullNameLabel => 'Nombre completo';

  @override
  String get fullNameHint => 'ej. Juan Pérez';

  @override
  String get emailLabel => 'Correo electrónico';

  @override
  String get emailHint => 'ej. juan@diamondgym.com';

  @override
  String get usernameLabel => 'Nombre de usuario';

  @override
  String get corporateEmailLabel => 'Correo corporativo';

  @override
  String get systemRoleLabel => 'Rol del sistema';

  @override
  String get assignedGymLabel => 'Gimnasio asignado';

  @override
  String get securitySectionTitle => 'Seguridad';

  @override
  String get passwordLabel => 'Contraseña';

  @override
  String get confirmPasswordLabel => 'Confirmar contraseña';

  @override
  String get newPasswordLabel => 'Nueva contraseña';

  @override
  String get resetPasswordButton => 'Restablecer contraseña';

  @override
  String get userActiveLabel => 'Usuario activo';

  @override
  String get userActiveSubtitleOn => 'El usuario puede acceder al sistema';

  @override
  String get userActiveSubtitleOff => 'El acceso al sistema está deshabilitado';

  @override
  String get cancelButton => 'Cancelar';

  @override
  String get createUserButton => 'Crear usuario';

  @override
  String get updateUserButton => 'Actualizar usuario';

  @override
  String get saveChangesButton => 'Guardar cambios';

  @override
  String get securityRequirementsTitle => 'Requisitos de seguridad';

  @override
  String get reqMinLength => 'Mínimo 8 caracteres';

  @override
  String get reqUppercase => 'Al menos una letra mayúscula';

  @override
  String get reqLowercase => 'Al menos una letra minúscula';

  @override
  String get reqDigit => 'Al menos un número';

  @override
  String get reqSpecialChar => 'Un carácter especial';

  @override
  String get successTitle => '¡Éxito!';

  @override
  String get successUserCreated => 'Usuario creado correctamente.';

  @override
  String get successUserUpdated => 'Usuario actualizado correctamente.';

  @override
  String get errorTitle => 'Error';

  @override
  String get passwordsDoNotMatch => 'Las contraseñas no coinciden';

  @override
  String get passwordRequiredNew =>
      'La contraseña es requerida para nuevos usuarios';

  @override
  String get passwordRequirementsFail =>
      'La contraseña no cumple con los requisitos de seguridad';

  @override
  String get nameEmailRequired =>
      'El nombre debe tener al menos 3 caracteres y el email es requerido';

  @override
  String get userFallbackName => 'Usuario';

  @override
  String createdLabel(String date) {
    return 'Creado: $date';
  }

  @override
  String get noGymsAvailable => 'No hay gimnasios disponibles';

  @override
  String get selectGymHint => 'Seleccione un gimnasio';

  @override
  String get gymsLoadError => 'Error cargando gimnasios';

  @override
  String get okButton => 'OK';

  @override
  String errorWithDetails(String details) {
    return 'Error: $details';
  }
}
