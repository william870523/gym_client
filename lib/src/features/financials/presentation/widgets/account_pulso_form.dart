import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../configuration/data/models/payment_type_model.dart';
import '../../../configuration/presentation/state/payment_type_notifier.dart';
import '../../data/models/account_model.dart';
import '../../data/models/currency_model.dart';
import '../state/currency_notifier.dart';

typedef AccountPulsoSubmit =
    Future<void> Function(String name, String currencyId, String? paymentTypeId);

class AccountPulsoForm extends ConsumerStatefulWidget {
  const AccountPulsoForm({super.key, this.account, required this.onSubmit});

  final AccountModel? account;
  final AccountPulsoSubmit onSubmit;

  @override
  ConsumerState<AccountPulsoForm> createState() => _AccountPulsoFormState();
}

class _AccountPulsoFormState extends ConsumerState<AccountPulsoForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  String? _currencyId;
  String? _paymentTypeId;
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.account != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account?.name);
    _currencyId = widget.account?.currencyId;
    _paymentTypeId = widget.account?.paymentTypeId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        _nameController.text.trim(),
        _currencyId!,
        _paymentTypeId,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'No se pudo guardar la cuenta: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PulsoThemeScope(
      child: Builder(
        builder: (context) {
          final tokens = PulsoTokens.of(context);
          final screen = MediaQuery.sizeOf(context);
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 620,
                maxHeight: screen.height - 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(height: 4, color: tokens.accent),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 20, 18),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final copy = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const PulsoLabel('PULSO · FINANZAS'),
                            const SizedBox(height: 9),
                            Text(
                              _isEdit ? 'EDITAR CUENTA' : 'NUEVA CUENTA',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Cada cuenta opera en una sola divisa del catálogo.',
                              style: TextStyle(
                                color: tokens.muted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        );
                        final actions = Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            PulsoSecondaryButton(
                              label: 'Cancelar',
                              onPressed: _busy
                                  ? null
                                  : () => Navigator.of(context).pop(false),
                            ),
                            PulsoPrimaryButton(
                              label: _isEdit ? 'Guardar cambios' : 'Crear',
                              onPressed: _submit,
                              busy: _busy,
                            ),
                          ],
                        );
                        if (constraints.maxWidth < 520) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              copy,
                              const SizedBox(height: 18),
                              actions,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(child: copy),
                            const SizedBox(width: 18),
                            actions,
                          ],
                        );
                      },
                    ),
                  ),
                  Divider(height: 1, color: tokens.line),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_error != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                color: tokens.dangerSoft,
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: tokens.danger,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                            const PulsoLabel('Identidad de la cuenta'),
                            const SizedBox(height: 12),
                            TextFormField(
                              key: const ValueKey('pulso-account-name'),
                              controller: _nameController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Nombre de la cuenta',
                                hintText: 'Ej. Caja principal',
                              ),
                              validator: _required,
                            ),
                            const SizedBox(height: 24),
                            const PulsoLabel('Divisa de operación'),
                            const SizedBox(height: 12),
                            _buildCurrencyField(context),
                            const SizedBox(height: 24),
                            const PulsoLabel('Tipo de pago asociado'),
                            const SizedBox(height: 12),
                            _buildPaymentTypeField(context),
                            if (_isEdit) ...[
                              const SizedBox(height: 18),
                              Text(
                                'ID · ${widget.account!.id}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: PulsoFonts.mono,
                                  fontSize: 10,
                                  color: tokens.muted2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Recibe el contexto del Builder interno: los tokens viven bajo el
  // PulsoThemeScope del propio formulario, no sobre el State del diálogo.
  Widget _buildCurrencyField(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final currenciesState = ref.watch(currencyProvider);
    return currenciesState.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (error, _) => Text(
        'No se pudo cargar el catálogo de monedas: $error',
        style: TextStyle(color: tokens.danger, fontSize: 12),
      ),
      data: (currencies) {
        final known = currencies.any((c) => c.id == _currencyId);
        return DropdownButtonFormField<String>(
          key: const ValueKey('pulso-account-currency'),
          initialValue: known ? _currencyId : null,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Moneda',
            hintText: 'Selecciona la divisa',
          ),
          items: [
            for (final currency in currencies)
              DropdownMenuItem(
                value: currency.id,
                child: _CurrencyOption(currency: currency),
              ),
          ],
          validator: (value) =>
              value == null ? 'Selecciona una divisa.' : null,
          onChanged: _busy
              ? null
              : (value) => setState(() => _currencyId = value),
        );
      },
    );
  }

  Widget _buildPaymentTypeField(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final typesState = ref.watch(paymentTypeNotifierProvider);
    return typesState.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (error, _) => Text(
        'No se pudo cargar los tipos de pago: $error',
        style: TextStyle(color: tokens.danger, fontSize: 12),
      ),
      data: (types) {
        // Se ofrecen los activos, más el asociado actual aunque esté inactivo
        // para no perder el vínculo al editar.
        final options = <PaymentTypeModel>[
          ...types.where((type) => type.active && !type.isDeleted),
        ];
        if (_paymentTypeId != null &&
            !options.any((type) => type.id == _paymentTypeId)) {
          for (final type in types) {
            if (type.id == _paymentTypeId) options.add(type);
          }
        }
        final known =
            _paymentTypeId == null ||
            options.any((type) => type.id == _paymentTypeId);
        return DropdownButtonFormField<String?>(
          key: const ValueKey('pulso-account-payment-type'),
          initialValue: known ? _paymentTypeId : null,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Tipo de pago (opcional)',
            helperText: 'Permite filtrar cuentas al registrar cobros.',
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Sin tipo asociado'),
            ),
            for (final type in options)
              DropdownMenuItem<String?>(
                value: type.id,
                child: Text(
                  type.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: _busy
              ? null
              : (value) => setState(() => _paymentTypeId = value),
        );
      },
    );
  }
}

class _CurrencyOption extends StatelessWidget {
  const _CurrencyOption({required this.currency});
  final CurrencyModel currency;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Row(
      children: [
        PulsoFlag(
          code: currency.code,
          base64String: currency.flagImage,
          width: 27,
          height: 18,
        ),
        const SizedBox(width: 10),
        Text(
          currency.code.toUpperCase(),
          style: const TextStyle(
            fontFamily: PulsoFonts.mono,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            currency.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: tokens.chalkDim),
          ),
        ),
      ],
    );
  }
}

String? _required(String? value) {
  return value?.trim().isNotEmpty == true ? null : 'Campo obligatorio.';
}
