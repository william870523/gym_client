import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/domain/models/user.dart';
import '../providers/users_provider.dart';
import 'create_user_screen.dart';

// Extensions for UI helpers
extension UserUI on User {
  String get initials {
    if (name.isEmpty) return email.isNotEmpty ? email[0].toUpperCase() : '?';
    return name
        .trim()
        .split(' ')
        .map((l) => l.isNotEmpty ? l[0] : '')
        .take(2)
        .join();
  }

  MaterialColor get roleColor {
    switch (role.toLowerCase()) {
      case 'admin':
      case 'administrador':
        return Colors.purple;
      case 'trainer':
      case 'entrenador':
        return Colors.blue;
      case 'reception':
      case 'recepción':
      case 'recepcion':
        return Colors.orange;
      case 'maintenance':
      case 'mantenimiento':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  MaterialColor get statusColor {
    return active ? Colors.green : Colors.grey;
  }
}

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  String? _selectedUserId;

  @override
  Widget build(BuildContext context) {
    // Custom Colors from Design
    const primaryColor = Color(0xFF136DEC);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Background based on Theme
    final backgroundColor = isDark
        ? const Color(0xFF101822)
        : const Color(0xFFF6F7F8);
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textMain = isDark ? Colors.white : const Color(0xFF0D131B);
    final textSec = isDark ? const Color(0xFF94A3B8) : const Color(0xFF4C6C9A);
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE7ECF3);

    final usersAsync = ref.watch(usersProvider);

    return Container(
      color: backgroundColor,
      child: Column(
        children: [
          // ---------------------------------------------------------
          // MAIN CONTENT
          // ---------------------------------------------------------
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1440),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT COLUMN (List)
                    Expanded(
                      flex: 8,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Page Header
                          _buildPageHeader(
                            textMain,
                            textSec,
                            borderColor,
                            surfaceColor,
                            usersAsync.maybeWhen(
                              data: (users) => users,
                              orElse: () => const [],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Toolbar
                          _buildToolbar(
                            surfaceColor,
                            borderColor,
                            textMain,
                            textSec,
                            primaryColor,
                          ),
                          const SizedBox(height: 24),

                          // Table
                          usersAsync.when(
                            data: (users) {
                              if (users.isEmpty) {
                                return Center(
                                  child: Text(
                                    "No hay usuarios encontrados",
                                    style: TextStyle(color: textSec),
                                  ),
                                );
                              }
                              return _buildUsersTable(
                                surfaceColor,
                                borderColor,
                                textMain,
                                textSec,
                                primaryColor,
                                users,
                              );
                            },
                            loading: () =>
                                Center(child: CircularProgressIndicator()),
                            error: (err, stack) => Center(
                              child: Text(
                                'Error: $err',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 32),

                    // RIGHT COLUMN (Detail Panel)
                    Expanded(
                      flex: 4,
                      child: usersAsync.when(
                        data: (users) {
                          User? selectedUser;
                          if (_selectedUserId != null) {
                            try {
                              selectedUser = users.firstWhere(
                                (u) => u.id == _selectedUserId,
                              );
                            } catch (_) {}
                          }
                          if (selectedUser == null && users.isNotEmpty) {
                            selectedUser = users.first;
                            // Defer state update to avoid build error
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted &&
                                  _selectedUserId != selectedUser!.id) {
                                setState(() {
                                  _selectedUserId = selectedUser!.id;
                                });
                              }
                            });
                          }

                          if (selectedUser == null) {
                            return SizedBox();
                          }

                          return StickyDetailPanel(
                            surface: surfaceColor,
                            border: borderColor,
                            textMain: textMain,
                            textSec: textSec,
                            primary: primaryColor,
                            user: selectedUser,
                            ref: ref,
                          );
                        },
                        loading: () => SizedBox(),
                        error: (_, __) => SizedBox(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ---------------------------------------------------------
          // FOOTER
          // ---------------------------------------------------------
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Center(
              child: Text(
                '© 2024 Diamond Gym Systems v2.4.1 | Soporte Técnico',
                style: TextStyle(color: textSec, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageHeader(
    Color textMain,
    Color textSec,
    Color border,
    Color surface,
    List<User> users,
  ) {
    final activeCount = users.where((u) => u.active).length;
    final inactiveCount = users.length - activeCount;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gestión de Usuarios',
              style: TextStyle(
                color: textMain,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Administración de personal y permisos de acceso',
              style: TextStyle(color: textSec, fontSize: 16),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                '$activeCount Activos',
                style: TextStyle(
                  color: textMain,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Container(
                width: 1,
                height: 16,
                color: border,
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),
              Text(
                '$inactiveCount Inactivos',
                style: TextStyle(color: textSec, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(
    Color surface,
    Color border,
    Color textMain,
    Color textSec,
    Color primary,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Search
          Expanded(
            child: TextField(
              style: TextStyle(
                color: textSec,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              onChanged: (value) {
                // Implement debounced search
                ref.read(usersProvider.notifier).refresh(query: value);
              },
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: textSec.withOpacity(0.1),
                hintText: 'Buscar por nombre, email o rol...',
                hintStyle: TextStyle(
                  color: textSec,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: Icon(Icons.search, color: textSec, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Filters
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: textSec.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.filter_list, color: textMain, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Filtros',
                      style: TextStyle(
                        color: textMain,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Add Button
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CreateUserScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: primary.withOpacity(0.4),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.add, size: 20),
            label: const Text(
              'Nuevo Usuario',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTable(
    Color surface,
    Color border,
    Color textMain,
    Color textSec,
    Color primary,
    List<User> users,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: textSec.withOpacity(0.05), // gray-50
              border: Border(bottom: BorderSide(color: border)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'USUARIO',
                    style: TextStyle(
                      color: textSec,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'ROL',
                    style: TextStyle(
                      color: textSec,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'ESTADO',
                    style: TextStyle(
                      color: textSec,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'ACCIONES',
                      style: TextStyle(
                        color: textSec,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Dynamic Rows
          ...users.map((user) {
            final isSelected = user.id == _selectedUserId;
            return _buildTableRow(
              user,
              isSelected,
              () => setState(() => _selectedUserId = user.id),
              textMain,
              textSec,
              border,
              primary,
            );
          }).toList(),

          // Pagination Footer (Simplified for now)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mostrando ${users.length} resultados',
                  style: TextStyle(color: textSec, fontSize: 13),
                ),
                Row(
                  children: [
                    _buildPaginationButton(
                      Icons.chevron_left,
                      false,
                      border,
                      textSec,
                    ),
                    _buildPaginationNumber('1', true, primary, Colors.white),
                    // _buildPaginationNumber('2', false, border, textSec),
                    _buildPaginationButton(
                      Icons.chevron_right,
                      false,
                      border,
                      textSec,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationButton(
    IconData icon,
    bool isActive,
    Color border,
    Color color,
  ) {
    return Container(
      width: 32,
      height: 32,
      margin: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }

  Widget _buildPaginationNumber(
    String text,
    bool isActive,
    Color activeBg,
    Color inactiveColor,
  ) {
    return Container(
      width: 32,
      height: 32,
      margin: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        color: isActive ? activeBg.withOpacity(0.1) : Colors.white,
        border: Border.all(
          color: isActive ? activeBg : inactiveColor.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: isActive ? activeBg : inactiveColor,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildTableRow(
    User user,
    bool isSelected,
    VoidCallback onTap,
    Color textMain,
    Color textSec,
    Color border,
    Color primary,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? primary.withOpacity(0.05) : null,
          border: Border(
            left: BorderSide(
              color: isSelected ? primary : Colors.transparent,
              width: 4,
            ),
            bottom: BorderSide(color: border),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: user.imageUrl != null && user.imageUrl!.isNotEmpty
                          ? Colors.transparent
                          : user.roleColor.shade100,
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                        color: user.imageUrl != null
                            ? Colors.transparent
                            : user.roleColor.shade200,
                      ),
                      image: user.imageUrl != null && user.imageUrl!.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(user.imageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: user.imageUrl == null || user.imageUrl!.isEmpty
                        ? Text(
                            user.initials,
                            style: TextStyle(
                              color: user.roleColor.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: TextStyle(
                            color: isSelected ? primary : textMain,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          user.email,
                          style: TextStyle(color: textSec, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildBadge(
                  user.role,
                  user.roleColor.shade100,
                  user.roleColor.shade800,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildStatusBadge(
                  user.active ? 'Activo' : 'Inactivo',
                  user.statusColor.shade100,
                  user.statusColor.shade800,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Align(
                alignment: Alignment.centerRight,
                child: isSelected
                    ? Icon(Icons.chevron_right, color: primary, size: 20)
                    : Icon(Icons.edit_outlined, color: textSec, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bg.withOpacity(0.5)), // Darker border
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bg.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            text.toUpperCase(),
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// Separate widget to handle scrolling/sticky behavior
class StickyDetailPanel extends StatelessWidget {
  final Color surface, border, textMain, textSec, primary;
  final User user;
  final WidgetRef ref;

  const StickyDetailPanel({
    super.key,
    required this.surface,
    required this.border,
    required this.textMain,
    required this.textSec,
    required this.primary,
    required this.user,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: textSec.withOpacity(0.05),
              border: Border(bottom: BorderSide(color: border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.manage_accounts, color: primary),
                    const SizedBox(width: 12),
                    Text(
                      'Editar Usuario',
                      style: TextStyle(
                        color: textMain,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () {
                        // Confirm Delete
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(
                              'Eliminar Usuario',
                              style: TextStyle(color: textMain),
                            ),
                            content: Text(
                              '¿Está seguro de que desea eliminar a ${user.name}?',
                              style: TextStyle(color: textSec),
                            ),
                            backgroundColor: surface,
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Cancelar'),
                              ),
                              TextButton(
                                onPressed: () {
                                  ref
                                      .read(usersProvider.notifier)
                                      .deleteUser(user.id);
                                  Navigator.pop(context);
                                  // Should also verify and maybe deselect
                                },
                                child: Text(
                                  'Eliminar',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Avatar
                Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                              ),
                            ],
                            color:
                                user.imageUrl == null || user.imageUrl!.isEmpty
                                ? user.roleColor.shade100
                                : Colors.grey.shade200,
                            image:
                                user.imageUrl != null &&
                                    user.imageUrl!.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(user.imageUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: user.imageUrl == null || user.imageUrl!.isEmpty
                              ? Center(
                                  child: Text(
                                    user.initials,
                                    style: TextStyle(
                                      color: user.roleColor.shade800,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user.name,
                      style: TextStyle(
                        color: textMain,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Form Fields (Read only in list view, or editable?)
                // The design implies an editable panel.
                // For now display data, with Edit button logic potentially opening CreateUserScreen in edit mode
                // OR implement inline editing here.
                // The original code had a "Guardar Cambios" button, suggesting inline editing.
                // For simplicity/robustness, let's just display info and use Edit button to open Dialog.
                _buildField(
                  'NOMBRE DE USUARIO',
                  Icons.person_outline,
                  user.name,
                  textMain,
                  textSec,
                  border,
                ),
                const SizedBox(height: 16),
                _buildField(
                  'EMAIL CORPORATIVO',
                  Icons.mail_outline,
                  user.email,
                  textMain,
                  textSec,
                  border,
                ),
                const SizedBox(height: 16),
                _buildField(
                  'ROL',
                  Icons.badge,
                  user.role,
                  textMain,
                  textSec,
                  border,
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.all(24),
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => CreateUserScreen(userToEdit: user),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text('Editar Información Completa'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    String label,
    IconData icon,
    String value,
    Color textMain,
    Color textSec,
    Color border,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: textSec,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: textSec.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, color: textSec, size: 20),
              SizedBox(width: 12),
              Text(
                value,
                style: TextStyle(color: textMain, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
