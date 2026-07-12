import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/registro_palette.dart';
import '../../../../core/widgets/base64_image.dart';
import '../../../../core/widgets/registro_widgets.dart';
import '../../../products/presentation/state/payment_plan_notifier.dart';
import '../../data/models/client_model.dart';
import '../state/client_notifier.dart';
import '../widgets/client_form.dart';

/// Clientes — "CENSOR DE CLIENTES" (F-02, sistema REGISTRO).
///
/// Ver docs/DESIGN_SYSTEM.md. Reutiliza [clientNotifierProvider] y [ClientForm].
class ClientsView extends ConsumerStatefulWidget {
  const ClientsView({super.key});

  @override
  ConsumerState<ClientsView> createState() => _ClientsViewState();
}

enum _ClientStatusFilter { all, active, inactive, expired }

enum _ClientSortKey { name, document, plan, validity, status }

class _ClientsViewState extends ConsumerState<ClientsView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final TextEditingController _fName = TextEditingController();
  final TextEditingController _fDoc = TextEditingController();
  final TextEditingController _fPlan = TextEditingController();
  final TextEditingController _fStatus = TextEditingController();

  String _searchQuery = '';
  _ClientStatusFilter _filter = _ClientStatusFilter.all;
  bool _filtersVisible = false;
  _ClientSortKey _sortKey = _ClientSortKey.name;
  bool _sortAsc = true;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _fName.dispose();
    _fDoc.dispose();
    _fPlan.dispose();
    _fStatus.dispose();
    super.dispose();
  }

  String _fullName(ClientModel client) {
    final first = client.nombres?.trim() ?? '';
    final last = client.apellidos?.trim() ?? '';
    final value = '$first $last'.trim();
    return value.isEmpty ? 'Cliente sin nombre' : value;
  }

  String _contactLine(ClientModel client) {
    final email = (client.correo ?? '').trim();
    final phone = client.telefono?.toString() ?? '';
    if (email.isNotEmpty && phone.isNotEmpty) {
      return '$email • $phone';
    }
    if (email.isNotEmpty) return email;
    if (phone.isNotEmpty) return phone;
    return 'Sin contacto';
  }

  bool _isExpired(ClientModel client) {
    if (client.endDate == null) return false;
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final normalizedEnd = DateTime(client.endDate!.year, client.endDate!.month, client.endDate!.day);
    return normalizedEnd.isBefore(normalizedToday);
  }

  void _openForm({ClientModel? client}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ClientForm(client: client),
    );
  }

  Future<void> _confirmDelete(ClientModel client) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await RegistroDeleteDialog.show(
      context,
      title: 'ELIMINAR SOCIO',
      message:
          '¿Eliminar al socio "${_fullName(client)}" (CI/DNI: ${client.id}) del censor? '
          'Se eliminarán sus registros asociados. Esta acción no se puede deshacer.',
    );

    if (confirmed != true) return;
    try {
      await ref.read(clientNotifierProvider.notifier).deleteClient(client.id);
      if (mounted && _selectedId == client.id) {
        setState(() => _selectedId = null);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Socio "${_fullName(client)}" eliminado.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error al eliminar: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  bool _matchesSearch(ClientModel client, Map<String, String> planLabels) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery;
    final planName = planLabels[client.planId ?? ''] ?? '';

    return _fullName(client).toLowerCase().contains(q) ||
        client.id.toLowerCase().contains(q) ||
        (client.correo ?? '').toLowerCase().contains(q) ||
        (client.telefono?.toString() ?? '').contains(q) ||
        planName.toLowerCase().contains(q);
  }

  bool _matchesFilter(ClientModel client) {
    switch (_filter) {
      case _ClientStatusFilter.active:
        return client.activo && !_isExpired(client);
      case _ClientStatusFilter.inactive:
        return !client.activo;
      case _ClientStatusFilter.expired:
        return _isExpired(client);
      case _ClientStatusFilter.all:
        return true;
    }
  }

  bool _matchesColumnFilters(ClientModel client, Map<String, String> planLabels) {
    bool has(TextEditingController t, String value) {
      final f = t.text.trim().toLowerCase();
      return f.isEmpty || value.toLowerCase().contains(f);
    }

    final planName = planLabels[client.planId ?? ''] ?? 'Sin plan';

    return has(_fName, _fullName(client)) &&
        has(_fDoc, client.id) &&
        has(_fPlan, planName) &&
        has(_fStatus, client.activo ? 'ACTIVO' : 'INACTIVO');
  }

  void _toggleSort(_ClientSortKey key) {
    setState(() {
      if (_sortKey == key) {
        _sortAsc = !_sortAsc;
      } else {
        _sortKey = key;
        _sortAsc = true;
      }
    });
  }

  List<ClientModel> _sortList(List<ClientModel> list, Map<String, String> planLabels) {
    final copy = List<ClientModel>.from(list);
    copy.sort((a, b) {
      int cmp;
      switch (_sortKey) {
        case _ClientSortKey.name:
          cmp = _fullName(a).toLowerCase().compareTo(_fullName(b).toLowerCase());
        case _ClientSortKey.document:
          cmp = a.id.compareTo(b.id);
        case _ClientSortKey.plan:
          final pA = planLabels[a.planId ?? ''] ?? '';
          final pB = planLabels[b.planId ?? ''] ?? '';
          cmp = pA.compareTo(pB);
        case _ClientSortKey.validity:
          final dA = a.endDate ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dB = b.endDate ?? DateTime.fromMillisecondsSinceEpoch(0);
          cmp = dA.compareTo(dB);
        case _ClientSortKey.status:
          cmp = (a.activo ? 1 : 0).compareTo(b.activo ? 1 : 0);
      }
      return _sortAsc ? cmp : -cmp;
    });
    return copy;
  }

  Widget _buildSummarySentence(
    RegistroPalette p,
    List<ClientModel> all,
    List<ClientModel> filtered,
  ) {
    final activeCount = all.where((c) => c.activo && !_isExpired(c)).length;
    final expiredCount = all.where(_isExpired).length;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: p.rule),
          bottom: BorderSide(color: p.rule),
        ),
      ),
      child: Text.rich(
        TextSpan(
          style: GoogleFonts.archivo(
            fontSize: 16,
            height: 1.45,
            color: p.ink2,
          ),
          children: [
            const TextSpan(text: 'El censor contiene '),
            TextSpan(
              text: '${all.length}',
              style: GoogleFonts.archivo(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: p.ink,
              ),
            ),
            TextSpan(
              text: all.length == 1 ? ' socio inscrito, con ' : ' socios inscritos, con ',
            ),
            TextSpan(
              text: '$activeCount',
              style: GoogleFonts.archivo(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: p.verm,
              ),
            ),
            const TextSpan(text: ' activos al día y '),
            TextSpan(
              text: '$expiredCount',
              style: GoogleFonts.archivo(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: expiredCount > 0 ? p.verm : p.ink,
              ),
            ),
            TextSpan(
              text: expiredCount == 1 ? ' con membresía vencida.' : ' con membresías vencidas.',
            ),
            if (filtered.length != all.length) ...[
              const TextSpan(text: ' (Filtrados '),
              TextSpan(
                text: '${filtered.length}',
                style: GoogleFonts.archivo(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: p.ink,
                ),
              ),
              const TextSpan(text: ' asientos de la consulta).'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMarginalia(
    RegistroPalette p,
    ClientModel? selected,
    Map<String, String> planLabels,
  ) {
    if (selected == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: p.paper2,
          border: Border(left: BorderSide(color: p.rule)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SIN SELECCIÓN',
              style: GoogleFonts.archivo(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
                color: p.ink3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Seleccione un cliente de la lista para ver su ficha completa, plan contratado y estado de vencimiento.',
              style: GoogleFonts.archivo(
                fontSize: 13,
                height: 1.4,
                color: p.ink2,
              ),
            ),
          ],
        ),
      );
    }

    final hasPhoto = selected.photoUrl != null && selected.photoUrl!.isNotEmpty;
    final planName = planLabels[selected.planId ?? ''] ?? 'Sin plan asignado';
    final expired = _isExpired(selected);

    String validityCaption = 'Sin fecha';
    if (selected.endDate != null) {
      final today = DateTime.now();
      final normalizedToday = DateTime(today.year, today.month, today.day);
      final normalizedEnd = DateTime(selected.endDate!.year, selected.endDate!.month, selected.endDate!.day);
      final days = normalizedEnd.difference(normalizedToday).inDays;

      if (days < 0) {
        validityCaption = 'VENCIDO (hace ${-days}d)';
      } else if (days == 0) {
        validityCaption = 'VENCE HOY';
      } else {
        validityCaption = 'VIGENTE ($days d restantes)';
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.paper2,
        border: Border(left: BorderSide(color: p.rule)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ASIENTO Y FICHA',
                style: GoogleFonts.archivo(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                  color: p.ink3,
                ),
              ),
              Text(
                'cli_${registroShortId(selected.id)}',
                style: GoogleFonts.fragmentMono(
                  fontSize: 11,
                  color: p.ink3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Foto carnet / figure
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: p.paper,
                border: Border.all(color: p.ruleStrong, width: 2),
              ),
              child: hasPhoto
                  ? Base64Image(
                      base64String: selected.photoUrl!,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    )
                  : Center(
                      child: Text(
                        _fullName(selected).substring(0, 1).toUpperCase(),
                        style: GoogleFonts.archivoBlack(
                          fontSize: 24,
                          color: p.verm,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _fullName(selected),
              textAlign: TextAlign.center,
              style: GoogleFonts.archivo(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: p.ink,
              ),
            ),
          ),
          Center(
            child: Text(
              'CI/DNI: ${selected.id}',
              textAlign: TextAlign.center,
              style: GoogleFonts.fragmentMono(
                fontSize: 11,
                color: p.ink3,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Dot leaders
          RegistroDotLeader(
            p: p,
            label: 'PLAN ACTUAL',
            value: planName.toUpperCase(),
          ),
          const SizedBox(height: 8),
          RegistroDotLeader(
            p: p,
            label: 'VENCIMIENTO',
            value: selected.endDate != null ? DateFormat('dd/MM/yyyy').format(selected.endDate!) : 'NO REGISTRADO',
            valueColor: expired ? p.verm : p.ink,
          ),
          const SizedBox(height: 8),
          RegistroDotLeader(
            p: p,
            label: 'ESTADO VIGENCIA',
            value: validityCaption,
            valueColor: expired ? p.verm : p.ink,
          ),
          const SizedBox(height: 8),
          RegistroDotLeader(
            p: p,
            label: 'TELÉFONO',
            value: selected.telefono?.toString() ?? 'NO REGISTRADO',
          ),
          const SizedBox(height: 8),
          RegistroDotLeader(
            p: p,
            label: 'CORREO',
            value: selected.correo?.isNotEmpty == true ? selected.correo! : 'NO REGISTRADO',
          ),
          const SizedBox(height: 8),
          RegistroDotLeader(
            p: p,
            label: 'ESTADO FICHA',
            value: selected.activo ? 'ACTIVO' : 'INACTIVO',
            valueColor: selected.activo ? p.ink : p.verm,
          ),
          const SizedBox(height: 20),

          Divider(height: 1, color: p.rule),
          const SizedBox(height: 16),

          // Actions
          RegistroTextAction(
            p: p,
            label: 'EDITAR FICHA →',
            prime: true,
            onTap: () => _openForm(client: selected),
          ),
          const SizedBox(height: 12),
          RegistroTextAction(
            p: p,
            label: 'ELIMINAR CLIENTE',
            onTap: () => _confirmDelete(selected),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = RegistroPalette.fromContext(context);
    final clientsAsync = ref.watch(clientNotifierProvider);
    final plansAsync = ref.watch(paymentPlanProvider);

    final planLabels = plansAsync.maybeWhen(
      data: (plans) => {
        for (final plan in plans)
          if (plan.id != null) plan.id!: plan.nombre,
      },
      orElse: () => const <String, String>{},
    );

    return Scaffold(
      backgroundColor: p.paper,
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
              _searchFocus.requestFocus(),
          const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
              _searchFocus.requestFocus(),
        },
        child: clientsAsync.when(
          loading: () => Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: p.verm,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'componiendo el censor de clientes…',
                  style: GoogleFonts.fragmentMono(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: p.ink3,
                  ),
                ),
              ],
            ),
          ),
          error: (err, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: RegistroErrorBlock(
              p: p,
              message: 'Error al cargar clientes: $err',
            ),
          ),
          data: (clients) {
            final filtered = clients
                .where((c) => _matchesSearch(c, planLabels))
                .where(_matchesFilter)
                .where((c) => _matchesColumnFilters(c, planLabels))
                .toList();

            final sorted = _sortList(filtered, planLabels);
            final activeCount = clients.where((c) => c.activo && !_isExpired(c)).length;
            final inactiveCount = clients.where((c) => !c.activo).length;
            final expiredCount = clients.where(_isExpired).length;

            ClientModel? selectedClient;
            if (_selectedId != null) {
              for (final c in clients) {
                if (c.id == _selectedId) {
                  selectedClient = c;
                  break;
                }
              }
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Membrete
                  RegistroMasthead(
                    p: p,
                    department: 'CENSOR Y MEMBRESÍAS',
                    code: 'F-02 / CLIENTES Y AFILIADOS · REV. 2026',
                  ),
                  const SizedBox(height: 16),

                  // Title + Text Actions
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(text: 'CENSOR DE\nCLIENTES'),
                              TextSpan(
                                text: '.',
                                style: TextStyle(color: p.verm),
                              ),
                            ],
                          ),
                          style: GoogleFonts.archivoBlack(
                            fontSize: 38,
                            height: 0.95,
                            color: p.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        children: [
                          RegistroTextAction(
                            p: p,
                            label: '↻ ACTUALIZAR',
                            onTap: () => ref.invalidate(clientNotifierProvider),
                          ),
                          RegistroTextAction(
                            p: p,
                            label: '＋ NUEVO CLIENTE',
                            prime: true,
                            onTap: () => _openForm(),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Summary sentence KPI
                  _buildSummarySentence(p, clients, sorted),
                  const SizedBox(height: 16),

                  // Command line: search + tabs
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 700;
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: RegistroSearchBar(
                                  p: p,
                                  controller: _searchController,
                                  focusNode: _searchFocus,
                                  hintText:
                                      'nombre, CI/DNI, correo, teléfono o plan… (Ctrl+K)',
                                  onChanged: (v) => setState(
                                    () => _searchQuery = v.trim().toLowerCase(),
                                  ),
                                  onClear: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                ),
                              ),
                              if (!isNarrow) const SizedBox(width: 24),
                              if (!isNarrow)
                                Wrap(
                                  spacing: 16,
                                  children: [
                                    RegistroTab(
                                      p: p,
                                      label: 'TODOS',
                                      count: clients.length,
                                      active: _filter == _ClientStatusFilter.all,
                                      onTap: () => setState(
                                        () => _filter = _ClientStatusFilter.all,
                                      ),
                                    ),
                                    RegistroTab(
                                      p: p,
                                      label: 'ACTIVOS',
                                      count: activeCount,
                                      active: _filter == _ClientStatusFilter.active,
                                      onTap: () => setState(
                                        () => _filter = _ClientStatusFilter.active,
                                      ),
                                    ),
                                    RegistroTab(
                                      p: p,
                                      label: 'VENCIDOS',
                                      count: expiredCount,
                                      active: _filter == _ClientStatusFilter.expired,
                                      onTap: () => setState(
                                        () => _filter = _ClientStatusFilter.expired,
                                      ),
                                    ),
                                    RegistroTab(
                                      p: p,
                                      label: 'INACTIVOS',
                                      count: inactiveCount,
                                      active: _filter == _ClientStatusFilter.inactive,
                                      onTap: () => setState(
                                        () => _filter = _ClientStatusFilter.inactive,
                                      ),
                                    ),
                                    RegistroTab(
                                      p: p,
                                      label: 'FILTROS ¶',
                                      count: null,
                                      active: _filtersVisible,
                                      onTap: () => setState(
                                        () => _filtersVisible = !_filtersVisible,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          if (isNarrow) const SizedBox(height: 12),
                          if (isNarrow)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  RegistroTab(
                                    p: p,
                                    label: 'TODOS',
                                    count: clients.length,
                                    active: _filter == _ClientStatusFilter.all,
                                    onTap: () => setState(
                                      () => _filter = _ClientStatusFilter.all,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  RegistroTab(
                                    p: p,
                                    label: 'ACTIVOS',
                                    count: activeCount,
                                    active: _filter == _ClientStatusFilter.active,
                                    onTap: () => setState(
                                      () => _filter = _ClientStatusFilter.active,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  RegistroTab(
                                    p: p,
                                    label: 'VENCIDOS',
                                    count: expiredCount,
                                    active: _filter == _ClientStatusFilter.expired,
                                    onTap: () => setState(
                                      () => _filter = _ClientStatusFilter.expired,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  RegistroTab(
                                    p: p,
                                    label: 'INACTIVOS',
                                    count: inactiveCount,
                                    active: _filter == _ClientStatusFilter.inactive,
                                    onTap: () => setState(
                                      () => _filter = _ClientStatusFilter.inactive,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  RegistroTab(
                                    p: p,
                                    label: 'FILTROS ¶',
                                    count: null,
                                    active: _filtersVisible,
                                    onTap: () => setState(
                                      () => _filtersVisible = !_filtersVisible,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),

                  // Column filters box
                  if (_filtersVisible) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      color: p.paper2,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _fName,
                              onChanged: (_) => setState(() {}),
                              cursorColor: p.verm,
                              style: GoogleFonts.fragmentMono(
                                fontSize: 12,
                                color: p.ink,
                              ),
                              decoration: InputDecoration(
                                hintText: 'filtro nombre…',
                                hintStyle: GoogleFonts.fragmentMono(
                                  fontSize: 12,
                                  color: p.ink4,
                                ),
                                isDense: true,
                                border: UnderlineInputBorder(
                                  borderSide: BorderSide(color: p.rule),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _fDoc,
                              onChanged: (_) => setState(() {}),
                              cursorColor: p.verm,
                              style: GoogleFonts.fragmentMono(
                                fontSize: 12,
                                color: p.ink,
                              ),
                              decoration: InputDecoration(
                                hintText: 'filtro documento…',
                                hintStyle: GoogleFonts.fragmentMono(
                                  fontSize: 12,
                                  color: p.ink4,
                                ),
                                isDense: true,
                                border: UnderlineInputBorder(
                                  borderSide: BorderSide(color: p.rule),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _fPlan,
                              onChanged: (_) => setState(() {}),
                              cursorColor: p.verm,
                              style: GoogleFonts.fragmentMono(
                                fontSize: 12,
                                color: p.ink,
                              ),
                              decoration: InputDecoration(
                                hintText: 'filtro plan…',
                                hintStyle: GoogleFonts.fragmentMono(
                                  fontSize: 12,
                                  color: p.ink4,
                                ),
                                isDense: true,
                                border: UnderlineInputBorder(
                                  borderSide: BorderSide(color: p.rule),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Table + Marginalia main section
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 960;

                      final tableWidget = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Table Header with rule 2px
                          Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: p.ruleStrong,
                                  width: 2,
                                ),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 10,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 38,
                                  child: Text('Nº', style: registroThStyle(p)),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: RegistroSortHead(
                                    p: p,
                                    label: 'SOCIO Y CONTACTO',
                                    active: _sortKey == _ClientSortKey.name,
                                    asc: _sortAsc,
                                    onTap: () =>
                                        _toggleSort(_ClientSortKey.name),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: RegistroSortHead(
                                    p: p,
                                    label: 'CI / DNI',
                                    active: _sortKey == _ClientSortKey.document,
                                    asc: _sortAsc,
                                    onTap: () =>
                                        _toggleSort(_ClientSortKey.document),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: RegistroSortHead(
                                    p: p,
                                    label: 'PLAN CONTRATADO',
                                    active: _sortKey == _ClientSortKey.plan,
                                    asc: _sortAsc,
                                    onTap: () =>
                                        _toggleSort(_ClientSortKey.plan),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: RegistroSortHead(
                                    p: p,
                                    label: 'VENCIMIENTO',
                                    active: _sortKey == _ClientSortKey.validity,
                                    asc: _sortAsc,
                                    onTap: () =>
                                        _toggleSort(_ClientSortKey.validity),
                                  ),
                                ),
                                SizedBox(
                                  width: 90,
                                  child: RegistroSortHead(
                                    p: p,
                                    label: 'ESTADO',
                                    active: _sortKey == _ClientSortKey.status,
                                    asc: _sortAsc,
                                    onTap: () =>
                                        _toggleSort(_ClientSortKey.status),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Rows block
                          if (sorted.isEmpty)
                            RegistroEmptyBlock(
                              p: p,
                              message:
                                  'No se encontraron clientes que coincidan con la búsqueda.',
                            )
                          else
                            RegistroScrollableRows(
                              p: p,
                              itemCount: sorted.length,
                              itemBuilder: (context, index) {
                                final item = sorted[index];
                                final isSelected = item.id == _selectedId;
                                final numStr = (index + 1)
                                    .toString()
                                    .padLeft(2, '0');
                                final planName = planLabels[item.planId ?? ''] ?? 'Sin plan';
                                final expired = _isExpired(item);

                                return MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () => setState(
                                      () => _selectedId = item.id,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                        horizontal: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? p.vermSoft
                                            : Colors.transparent,
                                        border: Border(
                                          left: BorderSide(
                                            color: isSelected
                                                ? p.verm
                                                : Colors.transparent,
                                            width: 3,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 35,
                                            child: Text(
                                              numStr,
                                              style: GoogleFonts.fragmentMono(
                                                fontSize: 11,
                                                color: isSelected
                                                    ? p.verm
                                                    : p.ink4,
                                                fontWeight: isSelected
                                                    ? FontWeight.w700
                                                    : FontWeight.w400,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _fullName(item),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: GoogleFonts.archivo(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: p.ink,
                                                  ),
                                                ),
                                                Text(
                                                  _contactLine(item),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style:
                                                      GoogleFonts.fragmentMono(
                                                    fontSize: 10.5,
                                                    color: p.ink3,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              item.id,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.fragmentMono(
                                                fontSize: 11.5,
                                                color: p.ink2,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              planName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.archivo(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                                color: p.ink2,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              item.endDate != null
                                                  ? DateFormat('dd/MM/yyyy').format(item.endDate!)
                                                  : 'Sin fecha',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.fragmentMono(
                                                fontSize: 11,
                                                fontWeight: expired ? FontWeight.w700 : FontWeight.w400,
                                                color: expired ? p.verm : p.ink2,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 90,
                                            child: Text(
                                              expired
                                                  ? 'VENCIDO'
                                                  : (item.activo ? 'ACTIVO' : 'INACTIVO'),
                                              style: GoogleFonts.fragmentMono(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                                color: expired || !item.activo
                                                    ? p.verm
                                                    : p.ink,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                          // Table colophon
                          Container(
                            padding: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: p.ruleStrong, width: 2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${sorted.length} de ${clients.length} asientos · orden: ${_sortKey.name} ${_sortAsc ? "↑" : "↓"}',
                                    style: GoogleFonts.fragmentMono(
                                      fontSize: 11,
                                      color: p.ink3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );

                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: tableWidget),
                            const SizedBox(width: 24),
                            SizedBox(
                              width: 280,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: KeyedSubtree(
                                  key: ValueKey(_selectedId),
                                  child: _buildMarginalia(p, selectedClient, planLabels),
                                ),
                              ),
                            ),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            tableWidget,
                            const SizedBox(height: 24),
                            _buildMarginalia(p, selectedClient, planLabels),
                          ],
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
