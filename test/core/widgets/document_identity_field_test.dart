import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/identity/document_type.dart';
import 'package:gym_client/src/core/widgets/cuba_ci_field.dart';
import 'package:gym_client/src/core/widgets/document_type_selector.dart';

void main() {
  testWidgets('usa combo y restringe la entrada según el tipo documental', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController();
    var documentType = DocumentType.cubanCi;
    var valid = false;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Form(
              key: formKey,
              child: ListView(
                children: [
                  DocumentTypeSelector(
                    value: documentType,
                    onChanged: (value) => setState(() => documentType = value),
                  ),
                  CubaCiField(
                    fieldKey: const ValueKey('document-field'),
                    controller: controller,
                    referenceDate: DateTime.utc(2026, 7, 25),
                    documentType: documentType,
                    decoration: const InputDecoration(labelText: 'Documento'),
                  ),
                  FilledButton(
                    onPressed: () => valid = formKey.currentState!.validate(),
                    child: const Text('Validar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.byType(DropdownButton<DocumentType>), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('document-field')),
      '91A-2',
    );
    await tester.pump();
    expect(controller.text, '912');
    expect(find.textContaining('primer dígito del mes'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('document-field')),
      '91024',
    );
    await tester.pump();
    expect(find.textContaining('primer dígito del día'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('document-field')),
      '25072520001',
    );
    await tester.pump();
    expect(find.textContaining('101 años'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('document-type-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pasaporte').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('document-field')),
      '02ab-12.,_34567',
    );
    await tester.tap(find.text('Validar'));
    await tester.pump();

    expect(valid, isTrue);
    expect(controller.text, '02AB12345');
    expect(find.textContaining('9/9'), findsOneWidget);
    expect(find.textContaining('autenticidad no verificada'), findsOneWidget);
  });
}
