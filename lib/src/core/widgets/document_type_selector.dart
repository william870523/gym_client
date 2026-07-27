import 'package:flutter/material.dart';

import '../identity/document_type.dart';

class DocumentTypeSelector extends StatelessWidget {
  const DocumentTypeSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.showUnknown = false,
  });

  final DocumentType value;
  final ValueChanged<DocumentType> onChanged;
  final bool enabled;
  final bool showUnknown;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final options = [
      DocumentType.cubanCi,
      DocumentType.passport,
      DocumentType.other,
      if (showUnknown) DocumentType.unknown,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Tipo de documento *',
            isDense: true,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<DocumentType>(
              key: const ValueKey('document-type-selector'),
              value: value,
              isDense: true,
              isExpanded: true,
              items: [
                for (final option in options)
                  DropdownMenuItem<DocumentType>(
                    key: ValueKey('document-type-${option.code}'),
                    value: option,
                    child: Text(option.label),
                  ),
              ],
              onChanged: enabled
                  ? (next) {
                      if (next != null) onChanged(next);
                    }
                  : null,
            ),
          ),
        ),
        if (value == DocumentType.unknown) ...[
          const SizedBox(height: 5),
          Text(
            'Registro heredado: clasifícalo si modificas el documento.',
            style: TextStyle(color: colors.tertiary, fontSize: 11),
          ),
        ],
      ],
    );
  }
}
