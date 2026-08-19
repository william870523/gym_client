import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/dashboard_nav_provider.dart';

import '../widgets/dashboard_sidebar.dart';
import '../widgets/dashboard_header.dart';
import 'pulso_dashboard_view.dart';
import '../../../clients/presentation/screens/clients_pulso_view.dart';
import '../../../financials/presentation/screens/currencies_pulso_view.dart';
import '../../../users/presentation/screens/users_pulso_view.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../attendance/presentation/screens/attendance_screen.dart';
import '../../../attendance/presentation/screens/daily_attendance_history_screen.dart';
import '../../../configuration/presentation/screens/nacionalidades_pulso_view.dart';
import '../../../configuration/presentation/screens/payment_types_pulso_view.dart';
import '../../../financials/presentation/screens/accounts_pulso_view.dart';
import '../../../gyms/presentation/screens/gyms_pulso_view.dart';
import '../../../schedules/presentation/screens/horarios_pulso_view.dart';
import '../../../products/presentation/screens/payment_plans_pulso_view.dart';
import '../../../configuration/presentation/screens/references_pulso_view.dart';
import '../../../financials/presentation/screens/exchange_rates_pulso_view.dart';
import '../../../trainers/presentation/screens/trainers_pulso_view.dart';
import '../../../payments/presentation/screens/payments_pulso_view.dart';
import '../../../accounting/presentation/screens/accounting_view.dart';
import '../../../accounting/presentation/screens/cierre_cadena_view.dart';
import '../../../settings/presentation/screens/appearance_pulso_view.dart';
import '../../../retention/presentation/screens/dropout_reasons_pulso_view.dart';
import '../../../statistics/presentation/screens/member_statistics_pulso_view.dart';
import '../../../statistics/presentation/screens/plan_statistics_pulso_view.dart';
import '../../../statistics/presentation/screens/trainer_statistics_pulso_view.dart';
import '../../../statistics/presentation/screens/statistics_rankings_pulso_view.dart';
import '../../../statistics/presentation/screens/statistics_ranking_explorer_pulso_view.dart';
import '../../../statistics/presentation/screens/statistics_segmentation_pulso_view.dart';
import '../../../statistics/presentation/screens/statistics_cohorts_pulso_view.dart';
import '../../../statistics/presentation/screens/statistics_accounting_pulso_view.dart';
import '../../../statistics/presentation/screens/statistics_forecast_pulso_view.dart';
import '../../../retention/presentation/screens/retention_pulso_view.dart';
import '../../../retention/presentation/screens/retention_settings_pulso_view.dart';
import '../../../clients/presentation/screens/client_discount_settings_pulso_view.dart';
import '../../../accounting/presentation/screens/exchange_revaluation_pulso_view.dart';

import '../../../auth/presentation/state/auth_notifier.dart';
import '../../domain/dashboard_access_policy.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Widget>? _cachedViews;
  String? _cachedRole;
  String? _cachedPermissions;
  bool _isLoggingOut = false;

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;

    try {
      await ref.read(authProvider.notifier).logout();
      ref.read(dashboardNavProvider.notifier).reset();
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } finally {
      _isLoggingOut = false;
    }
  }

  List<Widget> _getViews(String role, Set<String> permissions) {
    final permissionFingerprint = (permissions.toList()..sort()).join('|');
    if (_cachedViews != null &&
        _cachedRole == role &&
        _cachedPermissions == permissionFingerprint) {
      return _cachedViews!;
    }

    _cachedRole = role;
    _cachedPermissions = permissionFingerprint;
    // Igual que la barra lateral: acepta 'admin' y 'administrador',
    // sin distinguir mayúsculas.
    final normalizedRole = role.toLowerCase();
    final landing = switch (normalizedRole) {
      'admin' || 'administrador' => const PulsoAdminDashboardView(),
      'reception' ||
      'recepcion' ||
      'recepción' ||
      'recepcionista' => const PulsoReceptionDashboardView(),
      'accounting' || 'contabilidad' || 'contador' => _RoleAccessDashboard(
        eyebrow: 'CONTABILIDAD · CONTROL',
        title: 'PANEL CONTABLE.',
        description:
            'Tesorería, gastos e informes disponibles según la matriz RBAC.',
        permissions: permissions,
      ),
      'trainer' || 'entrenador' => _RoleAccessDashboard(
        eyebrow: 'ENTRENADOR · CONSULTA',
        title: 'PANEL DEL ENTRENADOR.',
        description: 'Socios y estadística disponibles en modo de consulta.',
        permissions: permissions,
      ),
      _ => _RoleAccessDashboard(
        eyebrow: 'ACCESO · RESTRINGIDO',
        title: 'SIN OPERACIÓN ASIGNADA.',
        description: 'Solicita a administración un rol válido del producto.',
        permissions: permissions,
      ),
    };
    _cachedViews = [
      // 0: Dashboard PULSO diferenciado por rol.
      landing,
      // 1: Clientes (PULSO; la versión REGISTRO se conserva como reversión)
      const ClientsPulsoView(),
      // 2: Classes (Placeholder)
      const Center(child: Text('Classes View - Coming Soon')),
      // 3: Libro de pagos (PULSO; la versión REGISTRO se conserva como
      // reversión)
      const PaymentsPulsoView(),
      // 4: Store (Placeholder)
      const Center(child: Text('Store View - Coming Soon')),
      // 5: Usuarios (PULSO; la versión REGISTRO se conserva como reversión)
      const UsersPulsoView(),
      const Center(child: Text('Roles View - Disabled')),
      // 7: Attendance
      const AttendanceScreen(),
      // 8: Ajustes → Apariencia (PULSO, Fase 2). Otros ajustes generales
      // siguen pendientes de definición de producto.
      const AppearancePulsoView(),
      // 9: Nacionalidades
      const NacionalidadesPulsoView(),
      // 10: Payment Types
      const PaymentTypesPulsoView(),
      // 11: Cuentas (PULSO; la versión REGISTRO se conserva como reversión)
      const AccountsPulsoView(),
      // 12: Gimnasios (PULSO; la versión REGISTRO se conserva como reversión)
      const GymsPulsoView(),
      // 13: Horarios (PULSO; la versión REGISTRO se conserva como reversión)
      const HorariosPulsoView(),
      // 14: Planes y tarifas (PULSO; la versión REGISTRO se conserva como
      // reversión)
      const PaymentPlansPulsoView(),
      // 15: References (PULSO; la versión REGISTRO se conserva como reversión)
      const ReferencesPulsoView(),
      // 16: Tipos de cambio (PULSO; la versión REGISTRO se conserva como
      // reversión y sigue en uso desde el detalle de pagos).
      const ExchangeRatesPulsoView(),
      // 17: Entrenadores (PULSO; la versión REGISTRO se conserva como
      // reversión)
      const TrainersPulsoView(),
      // 18: Monedas (PULSO promovida a destino oficial; la versión anterior
      // se conserva como reversión)
      const CurrenciesPulsoView(),
      // 19: Attendance History (HTML 2)
      const DailyAttendanceHistoryScreen(),
      // 20: Accounting
      AccountingView(permissions: permissions),
      // 21: Alias del destino oficial de Monedas (18). El piloto fue
      // promovido y su entrada de navegación retirada; el índice se conserva
      // para no desplazar el 22.
      const CurrenciesPulsoView(),
      // 22: Parte del turno (dashboard recepción) — accesible para previsualizar
      // desde el dashboard admin aunque se entre como administrador.
      const PulsoReceptionDashboardView(),
      // 23: Control y Calidad — cola operativa y métricas explicables de
      // renovación, gracia, salida y recuperación.
      const RetentionPulsoView(),
      // 24: Configuración administrativa de la política de retención.
      const RetentionSettingsPulsoView(),
      // 25: Configuración del descuento global de cliente VIEJO (R5.3).
      const ClientDiscountSettingsPulsoView(),
      // 26: Informe de revaluación cambiaria (R5.5).
      const ExchangeRevaluationPulsoView(),
      // 27: Catálogo de motivos de baja (E0-b, PLAN_ESTADISTICAS.md §7-ter).
      const DropoutReasonsPulsoView(),
      // 28: Portada comparativa y rankings (R6, PLAN_ESTADISTICAS.md §5.1).
      const StatisticsRankingsPulsoView(),
      // 29: Perfil estadístico del entrenador (R6, PLAN_ESTADISTICAS.md §4.1).
      const TrainerStatisticsPulsoView(showSelector: false),
      // 30: Perfil estadístico del plan, con la matriz de movilidad
      // (R6, PLAN_ESTADISTICAS.md §4.2).
      const PlanStatisticsPulsoView(showSelector: false),
      // 31: Perfil individual del socio. No tiene entrada duplicada en el menú:
      // se abre desde Clientes, donde ya existe la búsqueda por nombre/carné.
      const MemberStatisticsPulsoView(showSelector: false),
      // 32: tabla paginada de una medida estadística. Se abre desde los Top 5
      // y conserva período, moneda y destino de perfil.
      const StatisticsRankingExplorerPulsoView(),
      // 33: cruzador de segmentación (PLAN_ESTADISTICAS.md §5). Una vista con
      // dimensión × medida en lugar de una pantalla por pregunta.
      const StatisticsSegmentationPulsoView(),
      // 34: cohortes de alta 30/60/90, mapa de demanda observada y panel de
      // calidad de datos (PLAN_ESTADISTICAS.md §4.3, §5.2 y §5.3).
      const StatisticsCohortsPulsoView(),
      // 35: E4, capa visual de los readers contables canónicos.
      const StatisticsAccountingPulsoView(),
      // 36: E5, pronóstico de demanda con método y banda visibles.
      const StatisticsForecastPulsoView(),
      // 37: M6, contabilidad central de la cadena: semáforo, informe agregado,
      // certificado y detalle por sede, con un solo período mandando sobre las
      // cuatro (docs/MULTI_SEDE.md §6.3 y §6.4).
      const CierreCadenaView(),
    ];
    return _cachedViews!;
  }

  @override
  Widget build(BuildContext context) {
    // Theme Awareness — tokens "Registro" (papel y tinta, ver docs/DESIGN_SYSTEM.md)
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF16140F) // paper noche
        : const Color(0xFFF2EFE8); // paper día
    // La barra lateral y el contenido comparten el mismo papel;
    // los separa únicamente un filete de pelo.
    final surfaceColor = backgroundColor;
    final borderColor = isDark
        ? const Color(0xFF2E2A22) // rule noche
        : const Color(0xFFD8D3C6); // rule día
    final isCompact = MediaQuery.sizeOf(context).width < 840;

    // Role Logic
    final authState = ref.watch(authProvider);
    final role = authState.value?.role ?? 'user';
    final permissions = authState.value?.permissions.toSet() ?? <String>{};

    final rawViews = _getViews(role, permissions);
    // Navigation State
    final requestedIndex = ref.watch(dashboardNavProvider);
    final safeIndex =
        requestedIndex < rawViews.length &&
            dashboardIndexAllowed(requestedIndex, permissions)
        ? requestedIndex
        : 0;

    final views = rawViews.asMap().entries.map((entry) {
      return _LazyView(
        key: ValueKey('lazy_view_${entry.key}'),
        isVisible: safeIndex == entry.key,
        child: entry.value,
      );
    }).toList();

    // Title Logic
    String title = _getTitleForIndex(safeIndex, role);

    // Header Action
    Widget? actionButton;

    DashboardSidebar buildSidebar({required bool closeOnNavigate}) {
      return DashboardSidebar(
        isDark: isDark,
        surfaceColor: surfaceColor,
        borderColor: borderColor,
        selectedIndex: safeIndex,
        role: role,
        permissions: permissions,
        onNavigate: (index) {
          if (!dashboardIndexAllowed(index, permissions)) return;
          ref.read(dashboardNavProvider.notifier).setIndex(index);
          if (closeOnNavigate) {
            Navigator.of(context).pop();
          }
        },
        onLogout: _logout,
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: backgroundColor,
      drawer: isCompact
          ? Drawer(width: 300, child: buildSidebar(closeOnNavigate: true))
          : null,
      body: Row(
        children: [
          // Sidebar
          if (!isCompact) buildSidebar(closeOnNavigate: false),

          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Header
                DashboardHeader(
                  isDark: isDark,
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                  title: title,
                  role: role,
                  onToggleRole: () {},
                  onLogout: _logout,
                  onMenuPressed: isCompact
                      ? () => _scaffoldKey.currentState?.openDrawer()
                      : null,
                  headerAction: actionButton,
                ),

                // Content View (Scrollable via IndexedStack)
                Expanded(
                  child: IndexedStack(index: safeIndex, children: views),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTitleForIndex(int index, String role) {
    switch (index) {
      case 0:
        // El "Parte del día" (admin) trae su propio membrete interno.
        final r = role.toLowerCase();
        return (r == 'reception' ||
                r == 'recepcion' ||
                r == 'recepción' ||
                r == 'recepcionista')
            ? 'Recepción'
            : '';
      case 2:
        return 'Clases'; // Placeholder
      case 4:
        return 'Tienda'; // Placeholder
      case 6:
        return 'Roles Disabled'; // Placeholder
      case 8:
        return 'Configuración'; // Placeholder
      // Views with internal headers: Return empty to avoid duplication
      case 1: // Clients
      case 3: // Payments
      case 5: // Users
      case 7: // Attendance
      case 9: // Nacionalidades
      case 10: // Payment Types
      case 11: // Accounts
      case 12: // Gyms
      case 13: // Horarios
      case 14: // Payment Plans
      case 15: // References
      case 16: // Exchange Rates
      case 17: // Trainers
      case 18: // Currencies
        return '';
      case 19: // Attendance History
      case 20: // Accounting
      case 21: // Monedas PULSO (piloto)
      case 23: // Control y Calidad
      case 24: // Configuración de retención
      case 25: // Configuración de descuento de cliente
      case 26: // Revaluación cambiaria
      case 27: // Motivos de baja
      case 28: // Estadística del socio
      case 29: // Estadística del entrenador
      case 30: // Estadística del plan
      case 31: // Perfil estadístico del socio desde Clientes
      case 32: // Ranking estadístico completo
      case 33: // Cruzador de segmentación
      case 34: // Cohortes, demanda y calidad
      case 35: // Contabilidad gráfica
      case 36: // Pronóstico explicable
        return '';
      default:
        return '';
    }
  }
}

class _RoleAccessDashboard extends StatelessWidget {
  const _RoleAccessDashboard({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.permissions,
  });

  final String eyebrow;
  final String title;
  final String description;
  final Set<String> permissions;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? const Color(0xFFEFEAE0) : const Color(0xFF1C1A16);
    final muted = isDark ? const Color(0xFFA9A394) : const Color(0xFF6F695D);
    final rule = isDark ? const Color(0xFF3A352B) : const Color(0xFFD8D3C6);
    final sorted = permissions.toList()..sort();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: TextStyle(
              color: muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: ink,
              fontSize: 38,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(description, style: TextStyle(color: muted, fontSize: 15)),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(color: rule),
              color: isDark ? const Color(0xFF1D1A14) : const Color(0xFFF8F5EE),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PERMISOS ACTIVOS · ${sorted.length}',
                  style: TextStyle(
                    color: ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: sorted
                      .map(
                        (permission) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: rule),
                          ),
                          child: Text(
                            permission,
                            style: TextStyle(color: ink, fontSize: 12),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LazyView extends StatefulWidget {
  final Widget child;
  final bool isVisible;

  const _LazyView({super.key, required this.child, required this.isVisible});

  @override
  State<_LazyView> createState() => _LazyViewState();
}

class _LazyViewState extends State<_LazyView> {
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    if (widget.isVisible && !_initialized) {
      _initialized = true;
    }

    return SizedBox.expand(
      child: _initialized ? widget.child : const SizedBox.shrink(),
    );
  }
}
