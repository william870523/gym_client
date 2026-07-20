import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../data/models/exchange_revaluation_models.dart';
import '../state/accounting_providers.dart';

/// R5.5 — Informe de revaluación cambiaria (pérdida/ganancia por devaluación).
/// Solo lectura: valúa los cobros en moneda débil vivos al corte a la tasa del
/// cobro vs la tasa vigente al corte.
class ExchangeRevaluationPulsoView extends ConsumerStatefulWidget {
  const ExchangeRevaluationPulsoView({super.key});

  @override
  ConsumerState<ExchangeRevaluationPulsoView> createState() =>
      _ExchangeRevaluationPulsoViewState();
}

class _ExchangeRevaluationPulsoViewState
    extends ConsumerState<ExchangeRevaluationPulsoView> {
  /// Mes solicitado (`YYYY-MM`); null = mes comercial en curso del servidor.
  String? _month;

  void _step(String displayedMonth, int delta) {
    setState(() => _month = _shiftMonth(displayedMonth, delta));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(exchangeRevaluationProvider(_month));
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
                    _Header(
                      month: state.asData?.value.month ?? _month,
                      onPrev: state.hasValue
                          ? () => _step(state.value!.month, -1)
                          : null,
                      onNext: state.hasValue
                          ? () => _step(state.value!.month, 1)
                          : null,
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: state.when(
                        loading: () => const PulsoPanel(
                          child: PulsoStateView(
                            kind: PulsoStateKind.loading,
                            message: 'Valuando los cobros en moneda débil…',
                          ),
                        ),
                        error: (error, _) => PulsoPanel(
                          child: PulsoStateView(
                            kind: PulsoStateKind.error,
                            message:
                                'No se pudo calcular la revaluación.\n${_errorMessage(error)}',
                            onRetry: () => ref.invalidate(
                              exchangeRevaluationProvider(_month),
                            ),
                          ),
                        ),
                        data: (report) => _Body(report: report, compact: compact),
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

class _Header extends StatelessWidget {
  const _Header({required this.month, required this.onPrev, required this.onNext});

  final String? month;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

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
              PulsoLabel('CONTABILIDAD · CAMBIARIO'),
              Text(
                'REVALUACIÓN\nCAMBIARIA.',
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
    final selector = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PulsoIconButton(
          tooltip: 'Mes anterior',
          icon: Icons.chevron_left,
          onPressed: onPrev,
        ),
        Container(
          constraints: const BoxConstraints(minWidth: 96),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(border: Border.all(color: tokens.line)),
          child: Text(
            _monthLabel(month),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: tokens.chalk,
            ),
          ),
        ),
        PulsoIconButton(
          tooltip: 'Mes siguiente',
          icon: Icons.chevron_right,
          onPressed: onNext,
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerLeft, child: selector),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [Expanded(child: title), selector],
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.report, required this.compact});

  final ExchangeRevaluationModel report;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!report.hasBaseCurrency) {
      return PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.empty,
          message:
              'Configura la moneda base para valuar los cobros en moneda débil.\n${report.note}',
        ),
      );
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TotalBanner(report: report),
          const SizedBox(height: 12),
          if (report.currencies.isEmpty)
            const PulsoPanel(
              child: PulsoStateView(
                kind: PulsoStateKind.empty,
                message:
                    'No hay cobros en moneda débil vivos al corte en este mes.',
              ),
            )
          else
            for (final currency in report.currencies) ...[
              _CurrencyPanel(
                currency: currency,
                baseCode: report.baseCurrencyCode ?? '',
                compact: compact,
              ),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 2),
          _Limitations(limitations: report.limitations),
        ],
      ),
    );
  }
}

class _TotalBanner extends StatelessWidget {
  const _TotalBanner({required this.report});

  final ExchangeRevaluationModel report;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final color = report.isLoss
        ? tokens.danger
        : report.isGain
            ? tokens.success
            : tokens.chalkDim;
    final label = report.isLoss
        ? 'PÉRDIDA CAMBIARIA'
        : report.isGain
            ? 'GANANCIA CAMBIARIA'
            : 'SIN REVALUACIÓN';
    final base = report.baseCurrencyCode ?? '';
    return PulsoPanel(
      color: tokens.raised,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Row(
        children: [
          Container(width: 5, height: 52, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label · CORTE ${report.cutoffDate ?? report.month}',
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${report.totalRevaluation} $base',
                  style: TextStyle(
                    fontFamily: PulsoFonts.display,
                    fontSize: 34,
                    height: 0.95,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Sobre ${report.collections} cobro(s) en moneda débil vivos al corte'
                  '${report.collectionsWithoutCutoffRate > 0 ? ' · ${report.collectionsWithoutCutoffRate} sin tasa al corte' : ''}.',
                  style: TextStyle(fontSize: 10.5, color: tokens.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrencyPanel extends StatelessWidget {
  const _CurrencyPanel({
    required this.currency,
    required this.baseCode,
    required this.compact,
  });

  final ExchangeRevaluationCurrencyModel currency;
  final String baseCode;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final color = currency.isLoss
        ? tokens.danger
        : currency.isGain
            ? tokens.success
            : tokens.chalkDim;
    return PulsoPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PulsoLabel('MONEDA · ${currency.currencyCode}'),
              const Spacer(),
              Text(
                '${currency.collections} COBRO(S)',
                style: TextStyle(
                  fontFamily: PulsoFonts.mono,
                  fontSize: 7.5,
                  color: tokens.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _MoneyBlock(
                  caption: 'VALOR AL COBRO',
                  amount: currency.valueAtCollection,
                  suffix: baseCode,
                  color: tokens.chalkDim,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward, size: 16, color: tokens.muted),
              ),
              Expanded(
                child: _MoneyBlock(
                  caption: 'VALOR AL CORTE',
                  amount: currency.valueAtCutoff,
                  suffix: baseCode,
                  color: tokens.chalk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            color: tokens.raised,
            child: Row(
              children: [
                Text(
                  'REVALUACIÓN',
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: tokens.muted,
                  ),
                ),
                const Spacer(),
                Text(
                  '${currency.revaluation} $baseCode',
                  style: TextStyle(
                    fontFamily: PulsoFonts.display,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Importe cobrado: ${currency.amountWeak} ${currency.currencyCode}'
            '${currency.collectionsWithoutCutoffRate > 0 ? ' · ${currency.collectionsWithoutCutoffRate} sin tasa al corte' : ''}.',
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 8,
              color: tokens.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyBlock extends StatelessWidget {
  const _MoneyBlock({
    required this.caption,
    required this.amount,
    required this.suffix,
    required this.color,
  });

  final String caption;
  final String amount;
  final String suffix;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          caption,
          style: TextStyle(
            fontFamily: PulsoFonts.mono,
            fontSize: 7.5,
            color: tokens.muted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$amount $suffix',
          style: TextStyle(
            fontFamily: PulsoFonts.mono,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _Limitations extends StatelessWidget {
  const _Limitations({required this.limitations});

  final List<String> limitations;

  @override
  Widget build(BuildContext context) {
    if (limitations.isEmpty) return const SizedBox.shrink();
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      color: tokens.raised,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PulsoLabel('CÓMO LEER ESTE INFORME'),
          const SizedBox(height: 6),
          for (final item in limitations)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '· $item',
                style: TextStyle(
                  fontSize: 10,
                  height: 1.35,
                  color: tokens.muted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _monthLabel(String? month) {
  if (month == null || month.isEmpty) return 'EN CURSO';
  return month;
}

String _shiftMonth(String month, int delta) {
  final parts = month.split('-');
  if (parts.length != 2) return month;
  final year = int.tryParse(parts[0]);
  final monthNumber = int.tryParse(parts[1]);
  if (year == null || monthNumber == null) return month;
  final shifted = DateTime(year, monthNumber + delta);
  return '${shifted.year.toString().padLeft(4, '0')}-'
      '${shifted.month.toString().padLeft(2, '0')}';
}

String _errorMessage(Object error) {
  if (error is DioException && error.response?.data is Map) {
    final body = Map<String, dynamic>.from(error.response!.data as Map);
    return body['error']?.toString() ?? error.message ?? 'Error de red';
  }
  return error.toString().replaceFirst('Exception: ', '');
}
