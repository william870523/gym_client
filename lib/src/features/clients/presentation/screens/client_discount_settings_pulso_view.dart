import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../data/models/client_discount_settings_model.dart';
import '../../data/repositories/client_discount_repository.dart';
import '../../domain/client_discount.dart';
import '../state/client_discount_providers.dart';

/// R5.3 — Configuración administrativa del descuento global de cliente VIEJO.
///
/// Panel PULSO en Configuración para ajustar `DESCUENTO_CLIENTE_VIEJO_PCT`
/// (el % que hoy solo se editaba por endpoint). Enriquecido con una simulación
/// en vivo sobre los precios reales del gimnasio y con la nota del orden de
/// capas al cobrar (lista → descuento R5.3 → recargo R5.1).
class ClientDiscountSettingsPulsoView extends ConsumerStatefulWidget {
  const ClientDiscountSettingsPulsoView({super.key});

  @override
  ConsumerState<ClientDiscountSettingsPulsoView> createState() =>
      _ClientDiscountSettingsPulsoViewState();
}

class _ClientDiscountSettingsPulsoViewState
    extends ConsumerState<ClientDiscountSettingsPulsoView> {
  /// Precios de lista de referencia del gimnasio (mensual y trimestral),
  /// usados para la simulación. Coinciden con los precios conocidos 12 y 30.
  static const List<double> _referencePrices = [12.0, 30.0];
  static const List<String> _presets = ['10', '15', '16.67', '20', '25'];

  final TextEditingController _controller = TextEditingController();
  String? _savedPct;
  String? _loadedSignature;
  int _min = 0;
  int _max = 100;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _adopt(ClientDiscountSettingsModel settings) {
    final signature = [
      settings.clienteViejoPct,
      settings.source,
      settings.updatedAtUtc?.toIso8601String(),
    ].join(':');
    if (_loadedSignature == signature) return;
    _loadedSignature = signature;
    _savedPct = settings.clienteViejoPct;
    _min = settings.min;
    _max = settings.max;
    _controller.text = settings.clienteViejoPct;
  }

  /// % actualmente escrito, parseado; null si el texto no es un número válido.
  double? get _currentPct => double.tryParse(_controller.text.trim());

  bool get _valid {
    final value = _currentPct;
    return value != null && value >= _min && value <= _max;
  }

  bool get _dirty {
    final saved = double.tryParse(_savedPct ?? '');
    final current = _currentPct;
    if (current == null) return false;
    if (saved == null) return true;
    // Comparación por céntimos de punto para no marcar "16.7" vs "16.70".
    return (current * 100).round() != (saved * 100).round();
  }

  void _applyPreset(String preset) {
    _controller.text = preset;
    _controller.selection = TextSelection.collapsed(offset: preset.length);
    setState(() {});
  }

  Future<void> _save() async {
    if (_saving || !_dirty || !_valid) return;
    setState(() => _saving = true);
    try {
      final saved = await ref
          .read(clientDiscountRepositoryProvider)
          .update(clienteViejoPct: _controller.text.trim());
      if (!mounted) return;
      setState(() {
        _loadedSignature = null;
        _saving = false;
      });
      _adopt(saved);
      ref.invalidate(clientDiscountSettingsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Descuento guardado. Aplica a los próximos cobros de cliente VIEJO.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clientDiscountSettingsProvider);
    return PulsoThemeScope(
      child: Builder(
        builder: (context) => Material(
          color: PulsoTokens.of(context).floor,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 700;
              final padding = compact ? 16.0 : 32.0;
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  padding,
                  compact ? 16 : 22,
                  padding,
                  compact ? 16 : 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SettingsHeader(
                      dirty: _dirty,
                      saving: _saving,
                      onSave: _dirty && _valid ? _save : null,
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: state.when(
                        loading: () => const PulsoPanel(
                          child: PulsoStateView(
                            kind: PulsoStateKind.loading,
                            message: 'Leyendo el descuento del gimnasio…',
                          ),
                        ),
                        error: (error, _) => PulsoPanel(
                          child: PulsoStateView(
                            kind: PulsoStateKind.error,
                            message:
                                'No se pudo cargar el descuento.\n${_errorMessage(error)}',
                            onRetry: () =>
                                ref.invalidate(clientDiscountSettingsProvider),
                          ),
                        ),
                        data: (settings) {
                          _adopt(settings);
                          return _SettingsBody(
                            compact: compact,
                            controller: _controller,
                            currentPct: _currentPct,
                            valid: _valid,
                            min: _min,
                            max: _max,
                            source: settings.source,
                            presets: _presets,
                            referencePrices: _referencePrices,
                            onChanged: () => setState(() {}),
                            onPreset: _applyPreset,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({
    required this.dirty,
    required this.saving,
    required this.onSave,
  });

  final bool dirty;
  final bool saving;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final title = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 8, height: 66, color: tokens.accent),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PulsoLabel('CONFIGURACIÓN · COMERCIAL'),
              Text(
                'DESCUENTO\nCLIENTE VIEJO.',
                style: TextStyle(
                  fontFamily: PulsoFonts.display,
                  fontSize: 31,
                  height: 0.88,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    final status = Text(
      dirty ? 'CAMBIOS SIN GUARDAR' : 'DESCUENTO SIN CAMBIOS',
      style: TextStyle(
        fontFamily: PulsoFonts.mono,
        fontSize: 8,
        color: dirty ? tokens.warning : tokens.muted,
      ),
    );
    final button = PulsoPrimaryButton(
      label: 'Guardar descuento',
      icon: Icons.save_outlined,
      busy: saving,
      onPressed: onSave,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: status),
                  button,
                ],
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: title),
            Padding(
              padding: const EdgeInsets.only(right: 10, bottom: 5),
              child: status,
            ),
            button,
          ],
        );
      },
    );
  }
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody({
    required this.compact,
    required this.controller,
    required this.currentPct,
    required this.valid,
    required this.min,
    required this.max,
    required this.source,
    required this.presets,
    required this.referencePrices,
    required this.onChanged,
    required this.onPreset,
  });

  final bool compact;
  final TextEditingController controller;
  final double? currentPct;
  final bool valid;
  final int min;
  final int max;
  final String source;
  final List<String> presets;
  final List<double> referencePrices;
  final VoidCallback onChanged;
  final ValueChanged<String> onPreset;

  @override
  Widget build(BuildContext context) {
    final control = _DiscountControl(
      controller: controller,
      valid: valid,
      min: min,
      max: max,
      source: source,
      presets: presets,
      onChanged: onChanged,
      onPreset: onPreset,
    );
    final simulation = _DiscountSimulation(
      pct: currentPct,
      valid: valid,
      referencePrices: referencePrices,
    );
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (compact)
            Column(children: [control, const SizedBox(height: 12), simulation])
          else
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: control),
                  const SizedBox(width: 12),
                  Expanded(child: simulation),
                ],
              ),
            ),
          const SizedBox(height: 12),
          const _LayeringNotice(),
        ],
      ),
    );
  }
}

class _DiscountControl extends StatelessWidget {
  const _DiscountControl({
    required this.controller,
    required this.valid,
    required this.min,
    required this.max,
    required this.source,
    required this.presets,
    required this.onChanged,
    required this.onPreset,
  });

  final TextEditingController controller;
  final bool valid;
  final int min;
  final int max;
  final String source;
  final List<String> presets;
  final VoidCallback onChanged;
  final ValueChanged<String> onPreset;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const PulsoLabel('PORCENTAJE GLOBAL'),
              const Spacer(),
              Text(
                'ORIGEN · ${_sourceLabel(source)}',
                style: TextStyle(
                  fontFamily: PulsoFonts.mono,
                  fontSize: 7.5,
                  color: tokens.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'DESCUENTO DEL VIEJO',
            style: const TextStyle(
              fontFamily: PulsoFonts.display,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Se resta al precio de lista cuando el plan no fija un precio '
            'excepción para el cliente viejo.',
            style: TextStyle(fontSize: 10.5, height: 1.35, color: tokens.muted),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 156,
                child: TextField(
                  controller: controller,
                  onChanged: (_) => onChanged(),
                  textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  style: TextStyle(
                    fontFamily: PulsoFonts.display,
                    fontSize: 54,
                    height: 0.85,
                    fontWeight: FontWeight.w900,
                    color: valid ? tokens.accent : tokens.danger,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '%',
                  style: TextStyle(
                    fontFamily: PulsoFonts.display,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: tokens.chalkDim,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final preset in presets)
                ChoiceChip(
                  label: Text(preset),
                  selected: controller.text.trim() == preset,
                  onSelected: (_) => onPreset(preset),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            valid
                ? 'Rango permitido: $min–$max %, hasta 2 decimales'
                : 'Escribe un porcentaje entre $min y $max',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 7.5,
              color: valid ? tokens.muted : tokens.danger,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscountSimulation extends StatelessWidget {
  const _DiscountSimulation({
    required this.pct,
    required this.valid,
    required this.referencePrices,
  });

  final double? pct;
  final bool valid;
  final List<double> referencePrices;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PulsoLabel('SIMULACIÓN EN VIVO'),
          const SizedBox(height: 5),
          Text(
            'CÓMO QUEDA EL COBRO',
            style: const TextStyle(
              fontFamily: PulsoFonts.display,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Precio de lista → lo que paga un cliente viejo con este %. '
            'Los planes con precio excepción no usan el %.',
            style: TextStyle(fontSize: 10.5, height: 1.35, color: tokens.muted),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < referencePrices.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _SimulationRow(
              listPrice: referencePrices[i],
              pct: pct,
              valid: valid,
            ),
          ],
        ],
      ),
    );
  }
}

class _SimulationRow extends StatelessWidget {
  const _SimulationRow({
    required this.listPrice,
    required this.pct,
    required this.valid,
  });

  final double listPrice;
  final double? pct;
  final bool valid;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final breakdown = valid && pct != null
        ? clientDiscountBreakdown(
            listPrice: listPrice,
            category: ClientCategory.viejo,
            discountPct: pct!.toString(),
            planFixedOldPrice: null,
          )
        : null;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      color: tokens.raised,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LISTA',
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 7.5,
                    color: tokens.muted,
                  ),
                ),
                Text(
                  _money(listPrice),
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: tokens.chalkDim,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward, size: 16, color: tokens.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  breakdown == null
                      ? 'VIEJO'
                      : 'VIEJO · −${_money(breakdown.descuento)}',
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 7.5,
                    color: tokens.muted,
                  ),
                ),
                Text(
                  breakdown == null ? '—' : _money(breakdown.precioFinal),
                  style: TextStyle(
                    fontFamily: PulsoFonts.display,
                    fontSize: 26,
                    height: 0.95,
                    fontWeight: FontWeight.w900,
                    color: tokens.accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LayeringNotice extends StatelessWidget {
  const _LayeringNotice();

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      color: tokens.raised,
      padding: const EdgeInsets.all(15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.layers_outlined, color: tokens.accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PulsoLabel('ORDEN AL COBRAR'),
                const SizedBox(height: 3),
                Text(
                  'El cobro aplica en capas: precio de lista → descuento de '
                  'cliente viejo (este %) → recargo por método de pago. Un plan '
                  'con precio excepción para el viejo anula este % y fija la '
                  'cifra exacta. El cambio solo afecta cobros futuros; no '
                  'reescribe pagos ya emitidos.',
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.4,
                    color: tokens.chalkDim,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _money(double value) => value.toStringAsFixed(2);

String _sourceLabel(String value) => switch (value) {
  'GYM' => 'ESTE GIMNASIO',
  'GLOBAL' => 'POLÍTICA GLOBAL',
  _ => 'PREDETERMINADO',
};

String _errorMessage(Object error) {
  if (error is DioException && error.response?.data is Map) {
    final body = Map<String, dynamic>.from(error.response!.data as Map);
    return body['error']?.toString() ?? error.message ?? 'Error de red';
  }
  return error.toString().replaceFirst('Exception: ', '');
}
