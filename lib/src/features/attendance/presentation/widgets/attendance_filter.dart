import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AttendanceFilter extends StatelessWidget {
  const AttendanceFilter({super.key});

  @override
  Widget build(BuildContext context) {
    // Layout: Flex column on mobile, row on XL.
    // HTML: flex flex-col xl:flex-row gap-4 items-end bg-white p-5 rounded-xl border border-gray-200 shadow-sm

    final isWide = MediaQuery.of(context).size.width > 1280; // xl

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)), // gray-200
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Flex(
        direction: isWide ? Axis.horizontal : Axis.vertical,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Search Bar
          Expanded(
            flex: isWide ? 1 : 0,
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      "BÚSQUEDA RÁPIDA",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF64748B), // slate-500
                      ),
                    ),
                  ),
                  TextField(
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC), // slate-50
                      hintText: "Buscar por Nombre, CI o Membresía...",
                      hintStyle: GoogleFonts.inter(
                        color: const Color(0xFF94A3B8),
                      ), // slate-400
                      prefixIcon: Icon(
                        Icons.search,
                        color: const Color(0xFF135bec),
                        size: 24,
                      ),
                      suffixIcon: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "⌘ K",
                            style: GoogleFonts.robotoMono(
                              fontSize: 10,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Color(0xFFD1D5DB),
                        ), // gray-300
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Color(0xFFD1D5DB),
                        ), // gray-300
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Color(0xFF135bec),
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (!isWide) const SizedBox(height: 16),
          if (isWide) const SizedBox(width: 16),

          // Filters Row
          Expanded(
            flex: isWide ? 2 : 0, // Give more space to filters if wide
            child: SizedBox(
              width: isWide ? double.infinity : double.infinity,
              child: Row(
                children: [
                  // Date Filter
                  Expanded(
                    child: _FilterItem(
                      label: "FECHA",
                      child: TextField(
                        decoration: _filterInputDecoration(
                          Icons.calendar_today,
                          "24 Oct 2023",
                        ),
                        readOnly: true, // Mock date picker
                        style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Status Filter
                  Expanded(
                    child: _FilterItem(
                      label: "ESTADO",
                      child: DropdownButtonFormField<String>(
                        initialValue: "Todos",
                        decoration: _filterInputDecoration(null, null).copyWith(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                        ),
                        icon: const Icon(Icons.arrow_drop_down),
                        style: GoogleFonts.inter(
                          color: const Color(0xFF334155),
                          fontSize: 14,
                        ),
                        items: ["Todos", "Activos", "Vencidos", "Pendientes"]
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (v) {},
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Filter Button
                  Container(
                    height: 52, // Match input height
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFD1D5DB)),
                    ),
                    child: TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.filter_list,
                        color: Color(0xFF334155),
                      ),
                      label: Text(
                        "Filtros",
                        style: GoogleFonts.inter(
                          color: const Color(0xFF334155),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _filterInputDecoration(IconData? icon, String? placeholder) {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      prefixIcon: icon != null
          ? Icon(icon, color: const Color(0xFF94A3B8), size: 20)
          : null,
      hintText: placeholder,
      hintStyle: GoogleFonts.inter(
        color: const Color(0xFF334155),
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
    );
  }
}

class _FilterItem extends StatelessWidget {
  final String label;
  final Widget child;

  const _FilterItem({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF64748B),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
