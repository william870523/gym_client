import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../clients/data/repositories/multisede_access_repository.dart';
import '../../../configuration/presentation/widgets/global_catalog_authority.dart';
import '../../../financials/presentation/state/currency_notifier.dart';

/// Tarifa del acceso multi-sede, en la vista de Sedes (M4a).
///
/// **Vive aquí y no en la ficha del socio** aunque se venda allí: es un precio
/// de la cadena entera, y cambiarlo desde el expediente de una persona hace
/// creer que solo la afecta a ella. Esta es la pantalla donde el Dueño mira la
/// red, que es el ámbito real de este número.
///
/// El plus **no es un porcentaje del plan**: es una segunda suscripción con su
/// importe y su ciclo mensual propios (docs/MULTI_SEDE.md §9-bis).
class MultisedePricePanel extends ConsumerWidget {
  const MultisedePricePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PulsoTokens.of(context);
    final precio = ref.watch(multisedePrecioProvider);

    return PulsoPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: PulsoLabel('Acceso multi-sede · tarifa de la cadena')),
              PulsoLabel(
                precio.asData?.value == null ? 'SIN FIJAR' : 'GLOBAL',
                color: precio.asData?.value == null
                    ? tokens.warning
                    : tokens.muted2,
              ),
            ],
          ),
          const SizedBox(height: 10),
          precio.when(
            loading: () => const LinearProgressIndicator(minHeight: 2),
            error: (_, _) => Text(
              'No se pudo leer la tarifa.',
              style: TextStyle(color: tokens.danger, fontSize: 12),
            ),
            data: (fila) => Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: fila == null
                      ? Text(
                          'Sin tarifa: el plus no se puede vender todavía en ninguna sede.',
                          style: TextStyle(color: tokens.warning, fontSize: 13),
                        )
                      : Text(
                          fila.precio.toStringAsFixed(2),
                          style: TextStyle(
                            fontFamily: PulsoFonts.display,
                            fontSize: 31,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                            height: 1,
                            color: tokens.chalk,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                ),
                GlobalCatalogAuthority(
                  readOnly: PulsoLabel(
                    'La fija el dueño de la cadena',
                    color: tokens.muted2,
                  ),
                  child: PulsoSecondaryButton(
                    label: fila == null ? 'Fijar tarifa' : 'Cambiar',
                    icon: Icons.sell_outlined,
                    onPressed: () => _editar(context, ref, fila?.precio),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Se cobra aparte del plan, cada mes, y su ingreso es de la cadena. '
            'Cambiarla no reescribe lo que los socios ya pagaron.',
            style: TextStyle(color: tokens.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _editar(BuildContext context, WidgetRef ref, double? actual) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => _TarifaDialog(actual: actual),
    );
    if (guardado == true) ref.invalidate(multisedePrecioProvider);
  }
}

class _TarifaDialog extends ConsumerStatefulWidget {
  const _TarifaDialog({required this.actual});

  final double? actual;

  @override
  ConsumerState<_TarifaDialog> createState() => _TarifaDialogState();
}

class _TarifaDialogState extends ConsumerState<_TarifaDialog> {
  late final TextEditingController _precio = TextEditingController(
    text: widget.actual?.toStringAsFixed(2) ?? '',
  );
  String? _monedaId;
  String? _error;
  bool _guardando = false;

  @override
  void dispose() {
    _precio.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final valor = double.tryParse(_precio.text.trim().replaceAll(',', '.'));
    if (valor == null || valor < 0) {
      setState(() => _error = 'El importe tiene que ser un número no negativo.');
      return;
    }
    if (_monedaId == null) {
      setState(() => _error = 'Elija la moneda de la tarifa.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ref
          .read(multisedeAccessRepositoryProvider)
          .fijarPrecio(precio: valor, monedaId: _monedaId!);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final monedas = ref.watch(currencyProvider);
    return AlertDialog(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      backgroundColor: tokens.surface,
      title: const Text('Tarifa del acceso multi-sede'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Rige para todas las sedes desde el próximo cobro.',
              style: TextStyle(color: tokens.muted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _precio,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(labelText: 'Importe mensual'),
            ),
            const SizedBox(height: 12),
            monedas.when(
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (_, _) => Text(
                'No se pudieron leer las monedas.',
                style: TextStyle(color: tokens.danger, fontSize: 12),
              ),
              data: (lista) => DropdownButtonFormField<String>(
                initialValue: _monedaId,
                decoration: const InputDecoration(labelText: 'Moneda'),
                items: [
                  for (final moneda in lista)
                    DropdownMenuItem(
                      value: moneda.id,
                      child: Text('${moneda.code} · ${moneda.name}'),
                    ),
                ],
                onChanged: (valor) => setState(() => _monedaId = valor),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: tokens.danger, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        PulsoSecondaryButton(
          label: 'Cancelar',
          onPressed: _guardando ? null : () => Navigator.of(context).pop(false),
        ),
        PulsoPrimaryButton(
          label: 'Guardar tarifa',
          onPressed: _guardando ? null : _guardar,
        ),
      ],
    );
  }
}
