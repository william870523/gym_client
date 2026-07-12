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
import '../../../settings/presentation/screens/appearance_pulso_view.dart';

import '../../../auth/presentation/state/auth_notifier.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Widget>? _cachedViews;
  String? _cachedRole;

  List<Widget> _getViews(String role) {
    if (_cachedViews != null && _cachedRole == role) {
      return _cachedViews!;
    }

    _cachedRole = role;
    // Igual que la barra lateral: acepta 'admin' y 'administrador',
    // sin distinguir mayúsculas.
    final normalizedRole = role.toLowerCase();
    final isAdmin =
        normalizedRole == 'admin' || normalizedRole == 'administrador';
    _cachedViews = [
      // 0: Dashboard PULSO diferenciado por rol.
      // Admin: "Parte del día" (F-01); Recepción: "Parte del turno" (F-01R).
      isAdmin
          ? const PulsoAdminDashboardView()
          : const PulsoReceptionDashboardView(),
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
      const AccountingView(),
      // 21: Alias del destino oficial de Monedas (18). El piloto fue
      // promovido y su entrada de navegación retirada; el índice se conserva
      // para no desplazar el 22.
      const CurrenciesPulsoView(),
      // 22: Parte del turno (dashboard recepción) — accesible para previsualizar
      // desde el dashboard admin aunque se entre como administrador.
      const PulsoReceptionDashboardView(),
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

    final rawViews = _getViews(role);
    // Navigation State
    final selectedIndex = ref.watch(dashboardNavProvider);

    final views = rawViews.asMap().entries.map((entry) {
      return _LazyView(
        key: ValueKey('lazy_view_${entry.key}'),
        isVisible: selectedIndex == entry.key,
        child: entry.value,
      );
    }).toList();

    // Title Logic
    String title = _getTitleForIndex(selectedIndex, role);

    // Header Action
    Widget? actionButton;

    // Ensure we don't overflow if sidebar returns an index we haven't handled
    final safeIndex = selectedIndex < views.length ? selectedIndex : 0;

    DashboardSidebar buildSidebar({required bool closeOnNavigate}) {
      return DashboardSidebar(
        isDark: isDark,
        surfaceColor: surfaceColor,
        borderColor: borderColor,
        selectedIndex: selectedIndex,
        role: role,
        onNavigate: (index) {
          ref.read(dashboardNavProvider.notifier).setIndex(index);
          if (closeOnNavigate) {
            Navigator.of(context).pop();
          }
        },
        onLogout: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        },
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
                  onLogout: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
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
        return (r == 'admin' || r == 'administrador') ? '' : 'Recepción';
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
        return '';
      default:
        return '';
    }
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
