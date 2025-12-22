import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/dashboard_sidebar.dart';
import '../widgets/dashboard_header.dart';
import 'admin_dashboard_view.dart';
import 'reception_dashboard_view.dart';
import '../../../clients/presentation/screens/clients_view.dart';
import '../../../financials/presentation/screens/currencies_view.dart';
import '../../../users/presentation/screens/users_screen.dart';
import '../../../auth/presentation/screens/login_screen.dart';

// Mock Provider for Role Testing using Notifier (Riverpod 3 compatible)
class MockRoleNotifier extends Notifier<String> {
  @override
  String build() => 'admin';

  void update(String value) => state = value;
}

final mockRoleProvider = NotifierProvider<MockRoleNotifier, String>(
  MockRoleNotifier.new,
);

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Theme Awareness
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.grey.shade200;

    // Role Logic
    final role = ref.watch(mockRoleProvider);

    // Determine Title based on current view/role
    String title;
    if (_selectedIndex == 0) {
      title = role == 'admin' ? 'Dashboard Overview' : 'Recepción';
    } else if (_selectedIndex == 1) {
      title = 'Gestión de Clientes';
    } else if (_selectedIndex == 2) {
      title = 'Clases';
    } else if (_selectedIndex == 3) {
      title = 'Finanzas';
    } else if (_selectedIndex == 5) {
      // Users
      title = 'Gestión de Usuarios';
    } else {
      title = 'Configuración';
    }

    // Determine Header Action
    Widget? actionButton;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Row(
        children: [
          // Sidebar
          if (MediaQuery.of(context).size.width > 768) // Hide on mobile for now
            DashboardSidebar(
              isDark: isDark,
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              selectedIndex: _selectedIndex,
              role: role,
              onNavigate: (index) {
                setState(() => _selectedIndex = index);
              },
              onLogout: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            ),

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
                  onToggleRole: () {
                    final current = ref.read(mockRoleProvider);
                    ref
                        .read(mockRoleProvider.notifier)
                        .update(current == 'admin' ? 'reception' : 'admin');
                  },
                  onLogout: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  headerAction: actionButton,
                ),

                // Content View (Scrollable)
                Expanded(child: _buildContent(role)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(String role) {
    switch (_selectedIndex) {
      case 0:
        return role == 'admin'
            ? const AdminDashboardView()
            : const ReceptionDashboardView();
      case 1:
        return ClientsView();
      case 3:
        return CurrenciesView();
      case 5:
        return role == 'admin'
            ? const UsersScreen()
            : const Center(child: Text('Access Denied'));
      default:
        return Center(
          child: Text('Section $_selectedIndex Not Implemented Yet'),
        );
    }
  }
}
