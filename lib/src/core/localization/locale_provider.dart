import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    return const Locale('es');
  }

  void toggleLocale() {
    state = state.languageCode == 'es'
        ? const Locale('en')
        : const Locale('es');
  }

  void setLocale(Locale locale) {
    state = locale;
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(() {
  return LocaleNotifier();
});
