import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/features/financials/data/models/account_model.dart';

/// Unidad 03/06 (10-08-2026) — la moneda se nombra por su código, nunca por un
/// trozo de su identificador.
///
/// El recorrido web a 1280 px destapó que el diálogo de cobro escribía
/// «Saldo restante: ₽34.00 (~0.08 **1DBC5**)». `1DBC5` son los cinco primeros
/// caracteres de `1dbc5b00-5dfe-40a6-918d-4ca9edf203ad`, el `moneda_id` de la
/// cuenta en euros, cuyo `codigo` es `EUR`. La misma idea, copiada en el cartel
/// del recargo, exigía `currencyId.length <= 5` —condición que un UUID no
/// cumple nunca—, así que allí el importe salía **sin moneda**.
///
/// La prueba de R5.1 que ya existía no lo vio porque reimplementa la aritmética
/// del recargo y no toca la vista.
void main() {
  AccountModel cuenta({String? codigo, String id = 'cur-cup'}) => AccountModel(
    id: 'acc-1',
    name: 'Cuenta',
    currencyId: id,
    currencyCode: codigo,
    paymentTypeId: 'tp-1',
  );

  group('AccountCurrencyLabel', () {
    test('usa el código de la moneda cuando la cuenta lo trae', () {
      expect(cuenta(codigo: 'EUR').currencyLabel, 'EUR');
      expect(cuenta(codigo: 'cup').currencyLabel, 'CUP');
      expect(cuenta(codigo: '  usd  ').currencyLabel, 'USD');
    });

    test('nunca devuelve un trozo de UUID si hay código', () {
      // El caso exacto que se vio en pantalla.
      final eur = cuenta(
        codigo: 'EUR',
        id: '1dbc5b00-5dfe-40a6-918d-4ca9edf203ad',
      );

      expect(eur.currencyLabel, 'EUR');
      expect(eur.currencyLabel, isNot(contains('1DBC5')));
    });

    test('sin código cae al identificador recortado, no a cadena vacía', () {
      // Un importe sin moneda al lado es peor que un código feo: es
      // exactamente lo que «nunca sumar monedas distintas» quiere evitar.
      final sinCodigo = cuenta(id: '1dbc5b00-5dfe-40a6-918d-4ca9edf203ad');

      expect(sinCodigo.currencyLabel, '1DBC5');
      expect(sinCodigo.currencyLabel, isNotEmpty);
    });

    test('un código vacío o en blanco no se toma por bueno', () {
      expect(cuenta(codigo: '', id: 'cur-cup').currencyLabel, 'CUR-C');
      expect(cuenta(codigo: '   ', id: 'cur-cup').currencyLabel, 'CUR-C');
    });

    test('un identificador corto se muestra entero', () {
      expect(cuenta(id: 'eur').currencyLabel, 'EUR');
    });
  });
}
