// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get loginTagline =>
      'Power up your management.\nElevate your business.';

  @override
  String get loginDescription =>
      'Comprehensive control panel for efficient management of members, finances, and real-time access.';

  @override
  String get loginFeatureReports => 'Live Reports';

  @override
  String get loginFeatureAccess => 'Access Control';

  @override
  String get loginTitle => 'Sign in';

  @override
  String get loginSubtitle => 'Welcome to the GMS Administration Panel.';

  @override
  String get loginUsernameLabel => 'Username or email';

  @override
  String get loginUsernameHint => 'user@diamondgym.com';

  @override
  String get loginUsernameHelper => 'Enter your corporate email or user ID.';

  @override
  String get loginUsernameRequired => 'Enter your email or username';

  @override
  String get loginPasswordLabel => 'Password';

  @override
  String get loginForgotPassword => 'Forgot your password?';

  @override
  String get loginPasswordRequired => 'Enter your password';

  @override
  String get loginPasswordHelper =>
      'Minimum 8 characters, at least one number.';

  @override
  String get loginButton => 'Sign in';

  @override
  String get loginErrorUnexpected => 'Unexpected error';

  @override
  String get systemStatusLabel => 'System status';

  @override
  String get systemStatusOnline => 'ONLINE';

  @override
  String get toggleLanguageTooltip => 'Switch language';

  @override
  String get toggleThemeTooltip => 'Toggle theme';

  @override
  String get switchRoleTooltip => 'Switch role (debug)';

  @override
  String get logoutTooltip => 'Log out';

  @override
  String get searchMembersHint => 'Search members, classes...';

  @override
  String get invalidCredentialsError => 'Invalid credentials';

  @override
  String get userInactiveError => 'Account is inactive';

  @override
  String tooManyAttemptsError(int seconds) {
    return 'Too many failed attempts. Try again in $seconds seconds.';
  }

  @override
  String get tooManyAttemptsErrorGeneric =>
      'Too many failed attempts. Try again later.';

  @override
  String get networkError => 'Network error. Try again.';

  @override
  String get createUserTitle => 'Register new user';

  @override
  String get createUserSubtitle =>
      'Complete the form below to register a new team member.';

  @override
  String get fullNameLabel => 'Full name';

  @override
  String get fullNameHint => 'e.g. John Doe';

  @override
  String get emailLabel => 'Email address';

  @override
  String get emailHint => 'e.g. john@diamondgym.com';

  @override
  String get usernameLabel => 'Username';

  @override
  String get corporateEmailLabel => 'Corporate email';

  @override
  String get systemRoleLabel => 'System role';

  @override
  String get assignedGymLabel => 'Assigned gym';

  @override
  String get securitySectionTitle => 'Security';

  @override
  String get passwordLabel => 'Password';

  @override
  String get confirmPasswordLabel => 'Confirm password';

  @override
  String get newPasswordLabel => 'New password';

  @override
  String get resetPasswordButton => 'Reset password';

  @override
  String get userActiveLabel => 'User active';

  @override
  String get userActiveSubtitleOn => 'User can access the system';

  @override
  String get userActiveSubtitleOff => 'System access is disabled';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get createUserButton => 'Create user';

  @override
  String get updateUserButton => 'Update user';

  @override
  String get saveChangesButton => 'Save changes';

  @override
  String get securityRequirementsTitle => 'Security requirements';

  @override
  String get reqMinLength => 'Minimum 8 characters';

  @override
  String get reqUppercase => 'At least one uppercase letter';

  @override
  String get reqLowercase => 'At least one lowercase letter';

  @override
  String get reqDigit => 'At least one number';

  @override
  String get reqSpecialChar => 'One special character';

  @override
  String get successTitle => 'Success!';

  @override
  String get successUserCreated => 'User created successfully.';

  @override
  String get successUserUpdated => 'User updated successfully.';

  @override
  String get errorTitle => 'Error';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get passwordRequiredNew => 'Password is required for new users';

  @override
  String get passwordRequirementsFail =>
      'Password does not meet security requirements';

  @override
  String get nameEmailRequired =>
      'Name must be at least 3 characters and email is required';

  @override
  String get userFallbackName => 'User';

  @override
  String createdLabel(String date) {
    return 'Created: $date';
  }

  @override
  String get noGymsAvailable => 'No gyms available';

  @override
  String get selectGymHint => 'Select a gym';

  @override
  String get gymsLoadError => 'Error loading gyms';

  @override
  String get okButton => 'OK';

  @override
  String errorWithDetails(String details) {
    return 'Error: $details';
  }
}
