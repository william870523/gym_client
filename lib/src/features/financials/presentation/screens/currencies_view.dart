import 'package:flutter/material.dart';
import 'currencies_apple_view.dart';

/// Monedas — "REGISTRO DE DIVISAS" (F-03, sistema REGISTRO).
///
/// Reenvía directamente a la implementación oficial de referencia [CurrenciesAppleView].
/// Ver docs/DESIGN_SYSTEM.md.
class CurrenciesView extends StatelessWidget {
  const CurrenciesView({super.key});

  @override
  Widget build(BuildContext context) {
    return const CurrenciesAppleView();
  }
}
