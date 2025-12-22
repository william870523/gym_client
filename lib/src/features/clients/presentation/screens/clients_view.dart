import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Mock Client Model
class MockClient {
  final String id;
  final String name;
  final String email;
  final String plan;
  final String status;
  final String paymentDue;
  final String lastAccess;
  final String avatarUrl;
  final bool isDefaulter;
  final String sex;
  final String surname;
  final String dob;
  final String nationality;
  final String height;
  final String objective;

  MockClient({
    required this.id,
    required this.name,
    required this.email,
    required this.plan,
    required this.status,
    required this.paymentDue,
    required this.lastAccess,
    required this.avatarUrl,
    this.isDefaulter = false,
    this.sex = 'Masculino',
    this.surname = 'Pérez',
    this.dob = '12 Jun 1990',
    this.nationality = '🇲🇽 Mexicana',
    this.height = '1.78 m',
    this.objective = 'Hipertrofia',
  });
}

class ClientsView extends ConsumerStatefulWidget {
  const ClientsView({super.key});

  @override
  ConsumerState<ClientsView> createState() => _ClientsViewState();
}

class _ClientsViewState extends ConsumerState<ClientsView> {
  // Mock Data
  final List<MockClient> _clients = [
    MockClient(
      id: '4.567.890',
      name: 'Juan Pérez',
      email: 'juan.perez@email.com',
      plan: 'Premium',
      status: 'Activo',
      paymentDue: '15 Oct 2023',
      lastAccess: 'Hoy 09:30 AM',
      avatarUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuAWse_7BMeqLj1Ky2oo3bj5YcEikTfO-1L6M3UoDba51n99-rTGM7xEP7KopFuu1ZrMXf4x6pc42a2pzLjBlgFZL7q68tQjUkWhsnT1dr17cWUvhZmob1K1xI50K7ogXo3krJHc9I-n1E7I8RUI6cU4rgB2Qqxp4e3AM6ddtBlVox5wIJLD54Qf7K0xPP8sl4jH56bXxwJsPhtAGt-Md0qKIfsUl42NC9twBy4ZWXZQWk-Dxwfp9p4gSzY9za98JiRG22dW_fiAiE0',
    ),
    MockClient(
      id: '5.123.456',
      name: 'María García',
      email: 'maria.g@email.com',
      plan: 'Estándar',
      status: 'Moroso',
      paymentDue: '20 Sep 2023',
      lastAccess: 'Ayer 18:00 PM',
      avatarUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuBqxyQcLjl-rBhYl0wPOUuJm5thHMWUxM2jwATkBfJLvPNvR95fM2gnaMTBGg7aSQj2fJ6mN3wo27N4gHSuCEp2OTr7xbx1PuaPw1IIRQHi6piznvo__Z_WFNGb33eOyB6YpbROXKXZb-QZ9_tLP6l3-wUTV6fPFt17WPwMSO2O3k2qZ_SGd9o97CKLNOEYh4Z60HR_Dex-bF3ro7ezx6ddYc6pbZuXfkil49r23cVnOxakhAq-qc3Xz67sgsi2YETRuySHYhdBh5s',
      isDefaulter: true,
      sex: 'Femenino',
      surname: 'García',
      dob: '05 Mar 1995',
      nationality: '🇪🇸 Española',
      height: '1.65 m',
      objective: 'Pérdida de Peso',
    ),
    MockClient(
      id: '3.987.654',
      name: 'Carlos López',
      email: 'carlos.l@email.com',
      plan: 'Básico',
      status: 'Activo',
      paymentDue: '12 Oct 2023',
      lastAccess: '10 Oct 07:00 AM',
      avatarUrl: '', // Fallback to initials
      sex: 'Masculino',
      surname: 'López',
      dob: '22 Nov 1988',
      nationality: '🇦🇷 Argentina',
      height: '1.82 m',
      objective: 'Resistencia',
    ),
  ];

  String? _selectedClientId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.grey.shade200;

    return Row(
      children: [
        // Main Content (List)
        Expanded(
          flex: 8,
          child: Column(
            children: [
              // Sync Warning Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                color: Colors.red.shade50,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Icon(
                        Icons.sync_problem,
                        color: Colors.red.shade700,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Error de Sincronización',
                            style: TextStyle(
                              color: Colors.red.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text.rich(
                            TextSpan(
                              text:
                                  'No se pudieron guardar los cambios recientes de ',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 12,
                              ),
                              children: const [
                                TextSpan(
                                  text: '2 miembros',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(
                                  text: '. Reintentando automáticamente...',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        minimumSize: const Size(0, 32),
                      ),
                      child: const Text('Reintentar Ahora'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.red.shade400),
                      onPressed: () {},
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),

              // Toolbar (Filter / Search)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    // Search Bar
                    Expanded(
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Buscar por nombre, CI, email...',
                            border: InputBorder.none,
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.grey.shade400,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Filters
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildFilterChip('Todos', '842', true),
                        _buildFilterChip('Activos', '720', false),
                        _buildFilterChip(
                          'Morosos',
                          '15',
                          false,
                          color: Colors.red,
                        ),
                        _buildFilterChip(
                          'Por Vencer',
                          '42',
                          false,
                          color: Colors.orange,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Table
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 0,
                  ),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(
                        isDark ? Colors.black12 : Colors.grey.shade50,
                      ),
                      columns: const [
                        DataColumn(label: Text('Miembro')),
                        DataColumn(label: Text('CI / ID')),
                        DataColumn(label: Text('Plan')),
                        DataColumn(label: Text('Estado')),
                        DataColumn(label: Text('Próximo Pago'), numeric: true),
                        DataColumn(label: Text('Último Acceso'), numeric: true),
                        DataColumn(label: Text('Acciones')),
                      ],
                      rows: _clients.map((client) {
                        return DataRow(
                          selected: _selectedClientId == client.id,
                          onSelectChanged: (selected) {
                            setState(() {
                              _selectedClientId = selected == true
                                  ? client.id
                                  : null;
                            });
                          },
                          cells: [
                            DataCell(
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundImage: client.avatarUrl.isNotEmpty
                                        ? NetworkImage(client.avatarUrl)
                                        : null,
                                    backgroundColor: Colors.blue.shade100,
                                    child: client.avatarUrl.isEmpty
                                        ? Text(
                                            client.name.substring(0, 2),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        client.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        client.email,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              Chip(
                                label: Text(
                                  client.id,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                visualDensity: VisualDensity.compact,
                                backgroundColor: isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade100,
                              ),
                            ),
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    client.plan,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '\$45.00/mes',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: client.isDefaulter
                                      ? Colors.red.shade50
                                      : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(
                                    color: client.isDefaulter
                                        ? Colors.red.shade200
                                        : Colors.green.shade200,
                                  ),
                                ),
                                child: Text(
                                  client.status,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: client.isDefaulter
                                        ? Colors.red.shade700
                                        : Colors.green.shade700,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                client.paymentDue,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: client.isDefaulter
                                      ? Colors.red
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ),
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Hoy',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    client.lastAccess.split(' ').last +
                                        (client.lastAccess.contains('AM')
                                            ? ' AM'
                                            : ' PM'),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.visibility_outlined),
                                onPressed: () {
                                  setState(() {
                                    _selectedClientId = client.id;
                                  });
                                },
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              // Pagination Footer
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Mostrando 1 a 3 de 842 miembros',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.chevron_left),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Right Sidebar (Details Panel)
        if (_selectedClientId != null)
          _buildDetailsPanel(context, isDark, surfaceColor, borderColor),
      ],
    );
  }

  Widget _buildFilterChip(
    String label,
    String count,
    bool isActive, {
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? Colors.blue.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.blue.shade700 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: color != null
                  ? color.withOpacity(0.1)
                  : (isActive ? Colors.blue.shade100 : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              count,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color:
                    color ??
                    (isActive ? Colors.blue.shade700 : Colors.grey.shade600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsPanel(
    BuildContext context,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
  ) {
    final client = _clients.firstWhere((c) => c.id == _selectedClientId);

    return Container(
      width: 400,
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(left: BorderSide(color: borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(-4, 0),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: client.avatarUrl.isNotEmpty
                      ? NetworkImage(client.avatarUrl)
                      : null,
                  child: client.avatarUrl.isEmpty
                      ? Text(client.name.substring(0, 2))
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        client.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.blue.shade100),
                            ),
                            child: Text(
                              client.plan,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: client.isDefaulter
                                  ? Colors.red.shade50
                                  : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: client.isDefaulter
                                    ? Colors.red.shade100
                                    : Colors.green.shade100,
                              ),
                            ),
                            child: Text(
                              client.status,
                              style: TextStyle(
                                fontSize: 10,
                                color: client.isDefaulter
                                    ? Colors.red.shade700
                                    : Colors.green.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _selectedClientId = null;
                    });
                  },
                ),
              ],
            ),
          ),
          const Divider(),
          // Tabs
          Row(
            children: [
              Expanded(
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.blue, width: 2),
                    ),
                  ),
                  child: const Text(
                    'Datos Personales',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Pagos',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Asistencia',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ),
            ],
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Información General',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Editar'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(height: 16),

                  // Info Grid
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.grey.shade900
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: Wrap(
                      runSpacing: 16,
                      spacing: 16,
                      children: [
                        SizedBox(
                          width: 140,
                          child: _buildDetailRow('CI / Documento', client.id),
                        ),
                        SizedBox(
                          width: 140,
                          child: _buildDetailRow('Sexo', client.sex),
                        ),
                        SizedBox(
                          width: 140,
                          child: _buildDetailRow(
                            'Nombre',
                            client.name.split(' ').first,
                          ),
                        ),
                        SizedBox(
                          width: 140,
                          child: _buildDetailRow('Apellidos', client.surname),
                        ),
                        SizedBox(
                          width: 140,
                          child: _buildDetailRow('Fecha Nac.', client.dob),
                        ),
                        SizedBox(
                          width: 140,
                          child: _buildDetailRow(
                            'Nacionalidad',
                            client.nationality,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    'Físico y Objetivo',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.grey.shade900
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: Wrap(
                      runSpacing: 16,
                      spacing: 16,
                      children: [
                        SizedBox(
                          width: 140,
                          child: _buildDetailRow('Estatura', client.height),
                        ),
                        SizedBox(
                          width: 140,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Objetivo',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.shade50,
                                  border: Border.all(
                                    color: Colors.indigo.shade100,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  client.objective,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.indigo.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Footer Actions
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.edit_document, size: 18),
                    label: const Text('Editar'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.payments, size: 18),
                    label: const Text('Registrar Pago'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF136DEC),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
