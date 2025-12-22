import 'package:flutter/material.dart';

// Mock Currency Model
class MockCurrency {
  final String name;
  final String code;
  final String symbol;
  final Color color;

  MockCurrency({
    required this.name,
    required this.code,
    required this.symbol,
    required this.color,
  });
}

class CurrenciesView extends StatefulWidget {
  const CurrenciesView({super.key});

  @override
  State<CurrenciesView> createState() => _CurrenciesViewState();
}

class _CurrenciesViewState extends State<CurrenciesView> {
  final List<MockCurrency> _currencies = [
    MockCurrency(
      name: 'Dólar Estadounidense',
      code: 'USD',
      symbol: '\$',
      color: Colors.green,
    ),
    MockCurrency(name: 'Euro', code: 'EUR', symbol: '€', color: Colors.blue),
    MockCurrency(
      name: 'Peso Mexicano',
      code: 'MXN',
      symbol: '\$',
      color: Colors.orange,
    ),
    MockCurrency(
      name: 'Libra Esterlina',
      code: 'GBP',
      symbol: '£',
      color: Colors.purple,
    ),
    MockCurrency(
      name: 'Yen Japonés',
      code: 'JPY',
      symbol: '¥',
      color: Colors.red,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.grey.shade200;

    return Container(
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Finanzas',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Monedas',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gestión de Monedas',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Administra las divisas aceptadas para pagos y reportes.',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Nueva Moneda'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF136DEC),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre, código o símbolo...',
                      border: InputBorder.none,
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.grey.shade400,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.filter_list, size: 18),
                  label: const Text('Filtrar'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Exportar'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Table
          Expanded(
            child: Container(
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
                    DataColumn(label: Text('Nombre de la Moneda')),
                    DataColumn(label: Text('Código ISO')),
                    DataColumn(label: Text('Símbolo')),
                    DataColumn(label: Text('Acciones')),
                  ],
                  rows: _currencies.map((currency) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: currency.color.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    currency.symbol,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: currency.color,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                currency.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
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
                              color: isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDark
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: Text(
                              currency.code,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            currency.symbol,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 16,
                            ),
                          ),
                        ),
                        DataCell(
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () {},
                                color: Colors.grey.shade400,
                                tooltip: 'Editar',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () {},
                                color: Colors.grey.shade400,
                                tooltip: 'Eliminar',
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          // Pagination
          const SizedBox(height: 16),
          // Adding a simple pagination row similar to Clients view
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mostrando 1 a 5 de 12 resultados',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.chevron_left),
                    ),

                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF136DEC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '1',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      child: Text(
                        '2',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      child: Text(
                        '3',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
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
    );
  }
}
