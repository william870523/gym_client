import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/utils/datetime_zone.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../data/models/retention_models.dart';
import '../../data/repositories/retention_repository.dart';
import '../state/retention_providers.dart';

const _results = [
  'CONTACTADO',
  'PROMESA_PAGO',
  'NO_LOCALIZADO',
  'NO_DESEA_RENOVAR',
];
const _channels = ['WHATSAPP', 'LLAMADA', 'SMS', 'PRESENCIAL', 'OTRO'];

class RetentionManagementDialog extends ConsumerStatefulWidget {
  const RetentionManagementDialog({
    super.key,
    required this.item,
    required this.businessDate,
    required this.timezone,
  });

  final RetentionItemModel item;
  final String businessDate;
  final String timezone;

  @override
  ConsumerState<RetentionManagementDialog> createState() =>
      _RetentionManagementDialogState();
}

class _RetentionManagementDialogState
    extends ConsumerState<RetentionManagementDialog> {
  final _noteController = TextEditingController();
  String _result = 'CONTACTADO';
  String _channel = 'WHATSAPP';
  DateTime? _promiseDate;
  DateTime? _nextDate;
  bool _saving = false;

  DateTime get _today {
    final parts = widget.businessDate.split('-').map(int.parse).toList();
    return DateTime.utc(parts[0], parts[1], parts[2]);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _selectResult(String? value) {
    if (value == null) return;
    setState(() {
      _result = value;
      if (value == 'PROMESA_PAGO' && _promiseDate == null) {
        _promiseDate = _today.add(const Duration(days: 1));
        _nextDate ??= _promiseDate;
      } else if (value == 'NO_LOCALIZADO' && _nextDate == null) {
        _nextDate = _today.add(const Duration(days: 1));
      }
    });
  }

  Future<void> _pickDate({required bool promise}) async {
    final current = promise ? _promiseDate : _nextDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? _today,
      firstDate: _today,
      lastDate: _today.add(const Duration(days: 366)),
      helpText: promise ? 'FECHA PROMETIDA' : 'PRÓXIMA GESTIÓN',
    );
    if (picked == null || !mounted) return;
    final date = DateTime.utc(picked.year, picked.month, picked.day);
    setState(() {
      if (promise) {
        _promiseDate = date;
        if (_result == 'PROMESA_PAGO') _nextDate ??= date;
      } else {
        _nextDate = date;
      }
    });
  }

  Future<void> _save() async {
    if (_result == 'PROMESA_PAGO' && _promiseDate == null) {
      _message('Indica la fecha prometida de pago.');
      return;
    }
    if (_result == 'NO_DESEA_RENOVAR' &&
        _noteController.text.trim().length < 5) {
      _message('Registra una nota breve con el motivo.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(retentionRepositoryProvider)
          .createManagement(
            membershipId: widget.item.membershipId,
            result: _result,
            channel: _channel,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
            promiseDate: _dateOnly(_promiseDate),
            nextManagementDate: _dateOnly(_nextDate),
          );
      ref.invalidate(
        retentionManagementHistoryProvider(widget.item.membershipId),
      );
      ref.invalidate(retentionDashboardProvider);
      _noteController.clear();
      if (mounted) _message('Gestión registrada y enviada a sincronización.');
    } catch (error) {
      if (mounted) _message('No se pudo registrar la gestión: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return PulsoThemeScope(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tokens = PulsoTokens.of(context);
          final width = (constraints.maxWidth - 32).clamp(320.0, 960.0);
          final height = (constraints.maxHeight - 32).clamp(480.0, 760.0);
          return Center(
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                key: const ValueKey('retention-management-dialog'),
                width: width,
                height: height,
                child: PulsoPanel(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(tokens),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, body) {
                            if (body.maxWidth < 760) {
                              return ListView(
                                padding: const EdgeInsets.all(18),
                                children: [
                                  _form(context),
                                  const SizedBox(height: 22),
                                  Divider(color: tokens.line),
                                  const SizedBox(height: 14),
                                  const PulsoLabel('Historial de contactos'),
                                  const SizedBox(height: 8),
                                  SizedBox(height: 300, child: _history()),
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.all(22),
                                    child: _form(context),
                                  ),
                                ),
                                VerticalDivider(width: 1, color: tokens.line),
                                Expanded(
                                  flex: 5,
                                  child: Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        const PulsoLabel(
                                          'Historial de contactos',
                                        ),
                                        const SizedBox(height: 9),
                                        Expanded(child: _history()),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _header(PulsoTokens tokens) => Container(
    constraints: const BoxConstraints(minHeight: 84),
    padding: const EdgeInsets.fromLTRB(22, 14, 12, 14),
    color: tokens.raised,
    child: Row(
      children: [
        Container(width: 8, height: 44, color: tokens.accent),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PulsoLabel('RETENCIÓN · GESTIÓN OPERATIVA'),
              Text(
                widget.item.clientName.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: PulsoFonts.display,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  color: tokens.chalk,
                ),
              ),
              Text(
                '${widget.item.plan.name} · renovación ${_readable(widget.item.expectedRenewalDate)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: PulsoFonts.mono,
                  fontSize: 9.5,
                  color: tokens.muted,
                ),
              ),
            ],
          ),
        ),
        PulsoIconButton(
          tooltip: 'Cerrar',
          icon: Icons.close,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );

  Widget _form(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'La gestión documenta el contacto; no cambia por sí sola el pago ni la retención calculada.',
          style: TextStyle(fontSize: 11, height: 1.4, color: tokens.muted),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: const ValueKey('retention-result-field'),
          initialValue: _result,
          decoration: const InputDecoration(labelText: 'Resultado'),
          items: _results
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(_managementLabel(value)),
                ),
              )
              .toList(growable: false),
          onChanged: _selectResult,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _channel,
          decoration: const InputDecoration(labelText: 'Canal'),
          items: _channels
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(_channelLabel(value)),
                ),
              )
              .toList(growable: false),
          onChanged: (value) {
            if (value != null) setState(() => _channel = value);
          },
        ),
        if (_result == 'PROMESA_PAGO') ...[
          const SizedBox(height: 12),
          _DateField(
            label: 'Fecha prometida',
            value: _promiseDate,
            onTap: () => _pickDate(promise: true),
            onClear: () => setState(() => _promiseDate = null),
          ),
        ],
        if (_result != 'NO_DESEA_RENOVAR') ...[
          const SizedBox(height: 12),
          _DateField(
            label: 'Próxima gestión (opcional)',
            value: _nextDate,
            onTap: () => _pickDate(promise: false),
            onClear: () => setState(() => _nextDate = null),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('retention-note-field'),
          controller: _noteController,
          minLines: 3,
          maxLines: 5,
          maxLength: 1000,
          decoration: InputDecoration(
            labelText: _result == 'NO_DESEA_RENOVAR'
                ? 'Nota y motivo (obligatorio)'
                : 'Nota de la conversación',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: PulsoPrimaryButton(
            key: const ValueKey('save-retention-management'),
            label: 'Registrar gestión',
            icon: Icons.add_call,
            busy: _saving,
            onPressed: _saving ? null : _save,
          ),
        ),
      ],
    );
  }

  Widget _history() {
    final history = ref.watch(
      retentionManagementHistoryProvider(widget.item.membershipId),
    );
    return history.when(
      loading: () => const PulsoStateView(
        kind: PulsoStateKind.loading,
        message: 'Consultando gestiones…',
      ),
      error: (error, _) => PulsoStateView(
        kind: PulsoStateKind.error,
        message: 'No se pudo cargar el historial.\n$error',
        onRetry: () => ref.invalidate(
          retentionManagementHistoryProvider(widget.item.membershipId),
        ),
      ),
      data: (rows) => rows.isEmpty
          ? const PulsoStateView(
              kind: PulsoStateKind.empty,
              message: 'Aún no hay contactos registrados.',
            )
          : ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, index) =>
                  _HistoryLine(row: rows[index], timezone: widget.timezone),
            ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value == null
                  ? 'Sin fecha'
                  : DateFormat('dd/MM/yyyy').format(value!),
            ),
          ),
          if (value != null)
            IconButton(
              tooltip: 'Quitar fecha',
              icon: const Icon(Icons.close, size: 17),
              onPressed: onClear,
            ),
        ],
      ),
    ),
  );
}

class _HistoryLine extends StatelessWidget {
  const _HistoryLine({required this.row, required this.timezone});

  final RetentionManagementRecord row;
  final String timezone;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.raised,
        border: Border(left: BorderSide(color: tokens.accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _managementLabel(row.result).toUpperCase(),
                  style: TextStyle(
                    fontFamily: PulsoFonts.mono,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: tokens.chalk,
                  ),
                ),
              ),
              Text(
                _channelLabel(row.channel),
                style: TextStyle(fontSize: 9, color: tokens.muted),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '${row.registeredBy} · ${formatInZone(row.registeredAtUtc, timezone, DateFormat('dd/MM/yyyy · HH:mm'))}',
            style: TextStyle(
              fontFamily: PulsoFonts.mono,
              fontSize: 8.5,
              color: tokens.muted,
            ),
          ),
          if (row.promiseDate != null || row.nextManagementDate != null) ...[
            const SizedBox(height: 7),
            Text(
              [
                if (row.promiseDate != null)
                  'Promesa ${_readable(row.promiseDate!)}',
                if (row.nextManagementDate != null)
                  'Próxima ${_readable(row.nextManagementDate!)}',
              ].join(' · '),
              style: TextStyle(fontSize: 10, color: tokens.warning),
            ),
          ],
          if (row.note != null) ...[
            const SizedBox(height: 7),
            Text(
              row.note!,
              style: TextStyle(fontSize: 10.5, color: tokens.chalkDim),
            ),
          ],
        ],
      ),
    );
  }
}

String? _dateOnly(DateTime? value) =>
    value == null ? null : DateFormat('yyyy-MM-dd').format(value);

String _readable(String value) {
  final date = DateTime.tryParse('${value}T00:00:00Z');
  return date == null ? value : DateFormat('dd/MM/yyyy').format(date.toUtc());
}

String _managementLabel(String value) => switch (value) {
  'PENDIENTE' => 'Sin gestionar',
  'CONTACTADO' => 'Contactado',
  'PROMESA_PAGO' => 'Promesa de pago',
  'NO_LOCALIZADO' => 'No localizado',
  'NO_DESEA_RENOVAR' => 'No desea renovar',
  _ => value,
};

String _channelLabel(String value) => switch (value) {
  'WHATSAPP' => 'WhatsApp',
  'LLAMADA' => 'Llamada',
  'SMS' => 'SMS',
  'PRESENCIAL' => 'Presencial',
  'OTRO' => 'Otro',
  _ => value,
};
