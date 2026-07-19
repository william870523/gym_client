import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../data/models/retention_models.dart';
import '../../data/repositories/retention_repository.dart';
import '../state/retention_providers.dart';

class RetentionSettingsPulsoView extends ConsumerStatefulWidget {
  const RetentionSettingsPulsoView({super.key});

  @override
  ConsumerState<RetentionSettingsPulsoView> createState() =>
      _RetentionSettingsPulsoViewState();
}

class _RetentionSettingsPulsoViewState
    extends ConsumerState<RetentionSettingsPulsoView> {
  int? _graceDays;
  int? _horizonDays;
  int? _savedGraceDays;
  int? _savedHorizonDays;
  String? _loadedSignature;
  bool _saving = false;

  void _adopt(RetentionSettingsModel settings) {
    final signature = [
      settings.graceDays,
      settings.horizonDays,
      settings.updatedAtUtc?.toIso8601String(),
    ].join(':');
    if (_loadedSignature == signature) return;
    _loadedSignature = signature;
    _graceDays = settings.graceDays;
    _horizonDays = settings.horizonDays;
    _savedGraceDays = settings.graceDays;
    _savedHorizonDays = settings.horizonDays;
  }

  bool get _dirty =>
      _graceDays != _savedGraceDays || _horizonDays != _savedHorizonDays;

  Future<void> _save() async {
    if (_saving || !_dirty || _graceDays == null || _horizonDays == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await ref
          .read(retentionRepositoryProvider)
          .updateSettings(graceDays: _graceDays!, horizonDays: _horizonDays!);
      if (!mounted) return;
      setState(() {
        _loadedSignature = null;
        _saving = false;
      });
      _adopt(saved);
      ref.invalidate(retentionSettingsProvider);
      ref.invalidate(retentionDashboardProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Política guardada. Control y Calidad se recalculará.'),
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
    final state = ref.watch(retentionSettingsProvider);
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
                      onSave: _dirty ? _save : null,
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: state.when(
                        loading: () => const PulsoPanel(
                          child: PulsoStateView(
                            kind: PulsoStateKind.loading,
                            message: 'Leyendo la política del gimnasio…',
                          ),
                        ),
                        error: (error, _) => PulsoPanel(
                          child: PulsoStateView(
                            kind: PulsoStateKind.error,
                            message:
                                'No se pudo cargar la política.\n${_errorMessage(error)}',
                            onRetry: () =>
                                ref.invalidate(retentionSettingsProvider),
                          ),
                        ),
                        data: (settings) {
                          _adopt(settings);
                          return _SettingsBody(
                            settings: settings,
                            compact: compact,
                            graceDays: _graceDays!,
                            horizonDays: _horizonDays!,
                            onGraceChanged: (value) =>
                                setState(() => _graceDays = value),
                            onHorizonChanged: (value) =>
                                setState(() => _horizonDays = value),
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
              PulsoLabel('CONFIGURACIÓN · CONTROL Y CALIDAD'),
              Text(
                'POLÍTICA DE\nRETENCIÓN.',
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
      dirty ? 'CAMBIOS SIN GUARDAR' : 'POLÍTICA SIN CAMBIOS',
      style: TextStyle(
        fontFamily: PulsoFonts.mono,
        fontSize: 8,
        color: dirty ? tokens.warning : tokens.muted,
      ),
    );
    final button = PulsoPrimaryButton(
      label: 'Guardar política',
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
    required this.settings,
    required this.compact,
    required this.graceDays,
    required this.horizonDays,
    required this.onGraceChanged,
    required this.onHorizonChanged,
  });

  final RetentionSettingsModel settings;
  final bool compact;
  final int graceDays;
  final int horizonDays;
  final ValueChanged<int> onGraceChanged;
  final ValueChanged<int> onHorizonChanged;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PolicyTimeline(graceDays: graceDays, compact: compact),
        const SizedBox(height: 12),
        if (compact)
          Column(
            children: [
              _PolicyControl(
                key: const ValueKey('retention-grace-control'),
                eyebrow: 'REGLA 01',
                title: 'Días de gracia',
                description:
                    'Días posteriores al vencimiento en los que una renovación todavía cuenta como retenida.',
                value: graceDays,
                min: settings.graceMin,
                max: settings.graceMax,
                presets: const [0, 3, 5, 7, 10, 15],
                source: settings.graceSource,
                onChanged: onGraceChanged,
              ),
              const SizedBox(height: 12),
              _PolicyControl(
                key: const ValueKey('retention-horizon-control'),
                eyebrow: 'REGLA 02',
                title: 'Próximos a vigilar',
                description:
                    'Ventana futura que alimenta la cola antes de que llegue el vencimiento.',
                value: horizonDays,
                min: settings.horizonMin,
                max: settings.horizonMax,
                presets: const [7, 14, 21, 30, 60, 90],
                source: settings.horizonSource,
                onChanged: onHorizonChanged,
              ),
            ],
          )
        else
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _PolicyControl(
                    key: const ValueKey('retention-grace-control'),
                    eyebrow: 'REGLA 01',
                    title: 'Días de gracia',
                    description:
                        'Días posteriores al vencimiento en los que una renovación todavía cuenta como retenida.',
                    value: graceDays,
                    min: settings.graceMin,
                    max: settings.graceMax,
                    presets: const [0, 3, 5, 7, 10, 15],
                    source: settings.graceSource,
                    onChanged: onGraceChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PolicyControl(
                    key: const ValueKey('retention-horizon-control'),
                    eyebrow: 'REGLA 02',
                    title: 'Próximos a vigilar',
                    description:
                        'Ventana futura que alimenta la cola antes de que llegue el vencimiento.',
                    value: horizonDays,
                    min: settings.horizonMin,
                    max: settings.horizonMax,
                    presets: const [7, 14, 21, 30, 60, 90],
                    source: settings.horizonSource,
                    onChanged: onHorizonChanged,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        _ImpactNotice(horizonDays: horizonDays),
      ],
    ),
  );
}

class _PolicyTimeline extends StatelessWidget {
  const _PolicyTimeline({required this.graceDays, required this.compact});

  final int graceDays;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final items = [
      const _TimelineItem(
        number: '00',
        title: 'VENCE HOY',
        detail: 'renovación puntual',
      ),
      _TimelineItem(
        number: graceDays == 0 ? '—' : '01–$graceDays',
        title: graceDays == 0 ? 'SIN GRACIA' : 'EN GRACIA',
        detail: graceDays == 0
            ? 'no hay días adicionales'
            : 'todavía puede retenerse',
      ),
      _TimelineItem(
        number: '${graceDays + 1}'.padLeft(2, '0'),
        title: 'CAUSA SALIDA',
        detail: 'entra al cierre maduro',
        accent: true,
      ),
    ];
    return PulsoPanel(
      padding: EdgeInsets.zero,
      child: compact
          ? Column(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  if (index > 0) const Divider(height: 1),
                  items[index],
                ],
              ],
            )
          : Row(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  if (index > 0) const SizedBox(width: 1),
                  Expanded(child: items[index]),
                ],
              ],
            ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.number,
    required this.title,
    required this.detail,
    this.accent = false,
  });

  final String number;
  final String title;
  final String detail;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
      color: accent ? tokens.accentSoft : tokens.raised,
      child: Row(
        children: [
          Text(
            number,
            style: TextStyle(
              fontFamily: PulsoFonts.display,
              fontSize: 25,
              height: 0.9,
              fontWeight: FontWeight.w900,
              color: accent ? tokens.accent : tokens.chalk,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: accent ? tokens.accent : tokens.chalkDim,
                  ),
                ),
                Text(
                  detail,
                  style: TextStyle(fontSize: 10, color: tokens.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyControl extends StatelessWidget {
  const _PolicyControl({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.value,
    required this.min,
    required this.max,
    required this.presets,
    required this.source,
    required this.onChanged,
  });

  final String eyebrow;
  final String title;
  final String description;
  final int value;
  final int min;
  final int max;
  final List<int> presets;
  final String source;
  final ValueChanged<int> onChanged;

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
              PulsoLabel(eyebrow),
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
            title.toUpperCase(),
            style: const TextStyle(
              fontFamily: PulsoFonts.display,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            style: TextStyle(fontSize: 10.5, height: 1.35, color: tokens.muted),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PulsoIconButton(
                tooltip: 'Reducir $title',
                icon: Icons.remove,
                onPressed: value > min ? () => onChanged(value - 1) : null,
              ),
              SizedBox(
                width: 108,
                child: Text(
                  '$value',
                  key: ValueKey('${key.toString()}-value'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: PulsoFonts.display,
                    fontSize: 54,
                    height: 0.85,
                    fontWeight: FontWeight.w900,
                    color: tokens.accent,
                  ),
                ),
              ),
              PulsoIconButton(
                tooltip: 'Aumentar $title',
                icon: Icons.add,
                onPressed: value < max ? () => onChanged(value + 1) : null,
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
                  label: Text('$preset'),
                  selected: value == preset,
                  onSelected: (_) => onChanged(preset.clamp(min, max).toInt()),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Límite permitido: $min–$max días',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 7.5,
              color: tokens.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImpactNotice extends StatelessWidget {
  const _ImpactNotice({required this.horizonDays});

  final int horizonDays;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return PulsoPanel(
      color: tokens.raised,
      padding: const EdgeInsets.all(15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.rule_folder_outlined, color: tokens.accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PulsoLabel('IMPACTO ANTES DE GUARDAR'),
                const SizedBox(height: 3),
                Text(
                  'Control y Calidad vigilará los próximos $horizonDays días. El cambio reclasifica la proyección inmediatamente, pero no altera fechas contractuales, cobros, pausas ni historiales.',
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
