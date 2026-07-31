import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/pulso/pulso_theme.dart';
import '../../../../core/theme/pulso/pulso_tokens.dart';
import '../../../../core/widgets/pulso_charts.dart';
import '../../../../core/widgets/pulso_widgets.dart';
import '../../../clients/presentation/state/clients_scope_filter_provider.dart';
import '../../../dashboard/presentation/state/dashboard_nav_provider.dart';
import '../../../financials/data/models/currency_model.dart';
import '../../../financials/presentation/state/currency_notifier.dart';
import '../../data/models/statistics_segmentation.dart';
import '../../data/services/segmentation_saved_views_store.dart';
import '../../data/services/statistics_segmentation_export_service.dart';
import '../state/statistics_providers.dart';
import 'statistics_shared.dart';

/// Cruzador de segmentación (docs/PLAN_ESTADISTICAS.md §5).
///
/// Una vista en lugar de cuarenta: se elige por qué agrupar y qué contar. Lo
/// que la hace honesta y no un generador de cifras es que **el servidor manda
/// el catálogo y la definición de cada medida**, y que una combinación sin
/// sentido sale vacía y explicada en vez de en cero.
class StatisticsSegmentationPulsoView extends ConsumerWidget {
  const StatisticsSegmentationPulsoView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogo = ref.watch(segmentationCatalogProvider);
    final consulta = ref.watch(segmentationQueryProvider);
    final monedas = ref.watch(currencyProvider).value ?? const <CurrencyModel>[];

    return PulsoThemeScope(
      child: Builder(
        builder: (context) => ColoredBox(
          color: PulsoTokens.of(context).floor,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compacto = constraints.maxWidth < 900;
              return SingleChildScrollView(
                padding: EdgeInsets.all(compacto ? 16 : 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const StatsHeader(
                      etiqueta: 'Estadística · segmentación',
                      titulo: 'CRUZADOR',
                      descripcion:
                          'Elige por qué agrupar y qué contar. Cada medida '
                          'dice exactamente qué cuenta, toda tasa enseña su '
                          'denominador y las combinaciones sin sentido se '
                          'declaran vacías en vez de devolver cero.',
                    ),
                    const SizedBox(height: 14),
                    catalogo.when(
                      loading: () => const PulsoPanel(
                        child: PulsoStateView(
                          kind: PulsoStateKind.loading,
                          message: 'Cargando ejes disponibles…',
                        ),
                      ),
                      error: (error, _) => PulsoPanel(
                        child: PulsoStateView(
                          kind: PulsoStateKind.error,
                          message:
                              'No se pudo cargar el catálogo del cruzador.\n'
                              '${statisticsErrorMessage(error)}',
                          onRetry: () =>
                              ref.invalidate(segmentationCatalogProvider),
                        ),
                      ),
                      data: (data) => _Cuerpo(
                        catalogo: data,
                        consulta: consulta,
                        monedas: monedas,
                        compacto: compacto,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Cuerpo extends ConsumerWidget {
  const _Cuerpo({
    required this.catalogo,
    required this.consulta,
    required this.monedas,
    required this.compacto,
  });

  final SegmentationCatalog catalogo;
  final SegmentationQuery consulta;
  final List<CurrencyModel> monedas;
  final bool compacto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medida = catalogo.measureById(consulta.measure);
    // El dinero exige moneda, salvo cuando la moneda es el propio eje: ahí
    // sobra porque cada fila ya es una moneda.
    final exigeMoneda =
        (medida?.money ?? false) && consulta.dimension != 'moneda';
    final consultaEfectiva = exigeMoneda && consulta.currencyId == null
        ? consulta.copyWith(currencyId: monedas.firstOrNull?.id)
        : (exigeMoneda ? consulta : consulta.copyWith(clearCurrency: true));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Selectores(
          catalogo: catalogo,
          consulta: consulta,
          monedas: monedas,
          exigeMoneda: exigeMoneda,
        ),
        const SizedBox(height: 14),
        _VistasGuardadas(consulta: consultaEfectiva, catalogo: catalogo),
        const SizedBox(height: 14),
        if (exigeMoneda && consultaEfectiva.currencyId == null)
          const PulsoPanel(
            child: PulsoStateView(
              kind: PulsoStateKind.empty,
              message:
                  'Esta medida es dinero y no hay ninguna moneda cargada. '
                  'Sin moneda no se puede calcular sin mezclar divisas.',
            ),
          )
        else
          _Resultado(
            consulta: consultaEfectiva,
            monedas: monedas,
            compacto: compacto,
          ),
      ],
    );
  }
}

class _Selectores extends ConsumerWidget {
  const _Selectores({
    required this.catalogo,
    required this.consulta,
    required this.monedas,
    required this.exigeMoneda,
  });

  final SegmentationCatalog catalogo;
  final SegmentationQuery consulta;
  final List<CurrencyModel> monedas;
  final bool exigeMoneda;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(segmentationQueryProvider.notifier);
    return PulsoPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FilaSelector(
            etiqueta: 'AGRUPAR POR',
            child: DropdownButton<String>(
              key: const ValueKey('cruzador-dimension'),
              value: consulta.dimension,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: [
                for (final dimension in catalogo.dimensions)
                  DropdownMenuItem(
                    value: dimension.id,
                    child: Text(dimension.title),
                  ),
              ],
              onChanged: (valor) {
                if (valor != null) notifier.setDimension(valor);
              },
            ),
          ),
          const SizedBox(height: 8),
          _FilaSelector(
            etiqueta: 'CONTAR',
            child: DropdownButton<String>(
              key: const ValueKey('cruzador-medida'),
              value: consulta.measure,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: [
                for (final medida in catalogo.measures)
                  DropdownMenuItem(
                    value: medida.id,
                    child: Text(medida.title),
                  ),
              ],
              onChanged: (valor) {
                if (valor != null) notifier.setMeasure(valor);
              },
            ),
          ),
          if (exigeMoneda) ...[
            const SizedBox(height: 8),
            _FilaSelector(
              etiqueta: 'MONEDA',
              child: DropdownButton<String>(
                key: const ValueKey('cruzador-moneda'),
                value: consulta.currencyId ?? monedas.firstOrNull?.id,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                items: [
                  for (final moneda in monedas)
                    DropdownMenuItem(
                      value: moneda.id,
                      child: Text('${moneda.code} · ${moneda.name}'),
                    ),
                ],
                onChanged: notifier.setCurrency,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const PulsoLabel('PERÍODO'),
              for (final entrada in const [
                (30, '30 días'),
                (90, '90 días'),
                (365, '12 meses'),
              ])
                if (consulta.days == entrada.$1)
                  PulsoPrimaryButton(
                    label: entrada.$2,
                    onPressed: () => notifier.setDays(entrada.$1),
                  )
                else
                  PulsoSecondaryButton(
                    label: entrada.$2,
                    onPressed: () => notifier.setDays(entrada.$1),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilaSelector extends StatelessWidget {
  const _FilaSelector({required this.etiqueta, required this.child});
  final String etiqueta;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    return Row(
      children: [
        SizedBox(width: 108, child: PulsoLabel(etiqueta)),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(border: Border.all(color: tokens.line)),
            child: DropdownButtonHideUnderline(child: child),
          ),
        ),
      ],
    );
  }
}

/// Filtros guardados (§5). Una vista es el cruce entero —eje, medida, período y
/// moneda—, no solo el eje: recuperar media configuración obligaría a rehacer
/// la otra mitad y no ahorraría nada.
class _VistasGuardadas extends ConsumerWidget {
  const _VistasGuardadas({required this.consulta, required this.catalogo});

  final SegmentationQuery consulta;
  final SegmentationCatalog catalogo;

  String _describir(SegmentationSavedView vista) {
    final medida = catalogo.measureById(vista.query.measure)?.title ??
        vista.query.measure;
    final dimension = catalogo.dimensions
        .where((d) => d.id == vista.query.dimension)
        .map((d) => d.title)
        .firstOrNull ??
        vista.query.dimension;
    return '$medida por ${dimension.toLowerCase()} · ${vista.query.days} d';
  }

  Future<void> _guardar(BuildContext context, WidgetRef ref) async {
    final controlador = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Guardar esta vista'),
        content: TextField(
          controller: controlador,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            hintText: 'Por ejemplo: ingreso por medio de pago',
          ),
          onSubmitted: (valor) => Navigator.of(context).pop(valor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controlador.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controlador.dispose();
    if (nombre == null || nombre.trim().isEmpty) return;
    await ref
        .read(segmentationSavedViewsProvider.notifier)
        .guardar(nombre, consulta);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PulsoTokens.of(context);
    final vistas = ref.watch(segmentationSavedViewsProvider);
    final guardadas = vistas.value ?? const <SegmentationSavedView>[];

    return PulsoPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: PulsoLabel('VISTAS GUARDADAS')),
              PulsoSecondaryButton(
                key: const ValueKey('cruzador-guardar-vista'),
                label: 'Guardar esta vista',
                icon: Icons.bookmark_add_outlined,
                onPressed: () => _guardar(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (guardadas.isEmpty)
            Text(
              'Todavía no hay ninguna. Guardar una deja el cruce entero —eje, '
              'medida, período y moneda— listo para volver de un toque.',
              key: const ValueKey('cruzador-sin-vistas'),
              style: TextStyle(fontSize: 10, color: tokens.muted),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final vista in guardadas)
                  InputChip(
                    key: ValueKey('cruzador-vista-${vista.name}'),
                    label: Text('${vista.name} · ${_describir(vista)}'),
                    onPressed: () {
                      final notifier = ref.read(
                        segmentationQueryProvider.notifier,
                      );
                      notifier.setDimension(vista.query.dimension);
                      notifier.setMeasure(vista.query.measure);
                      notifier.setDays(vista.query.days);
                      notifier.setCurrency(vista.query.currencyId);
                    },
                    onDeleted: () => ref
                        .read(segmentationSavedViewsProvider.notifier)
                        .borrar(vista.name),
                    deleteIcon: const Icon(Icons.close, size: 14),
                  ),
              ],
            ),
          const SizedBox(height: 8),
          Text(
            'Son de este puesto y de esta cuenta: quien entre desde el '
            'navegador verá las suyas, no estas.',
            style: TextStyle(fontSize: 9, color: tokens.muted2),
          ),
        ],
      ),
    );
  }
}

/// Fila de la tabla. Solo es pulsable cuando hay adónde ir; si no, se dibuja
/// igual pero sin invitar a un gesto que no lleva a ninguna parte.
class _FilaTabla extends StatelessWidget {
  const _FilaTabla({
    required this.clave,
    required this.onTap,
    required this.child,
  });

  final String clave;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final contenido = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: child,
    );
    if (onTap == null) {
      return KeyedSubtree(key: ValueKey('cruzador-fila-$clave'), child: contenido);
    }
    return InkWell(
      key: ValueKey('cruzador-fila-$clave'),
      onTap: onTap,
      child: contenido,
    );
  }
}

class _Resultado extends ConsumerWidget {
  const _Resultado({
    required this.consulta,
    required this.monedas,
    required this.compacto,
  });

  final SegmentationQuery consulta;
  final List<CurrencyModel> monedas;
  final bool compacto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(segmentationProvider(consulta));
    return estado.when(
      loading: () => const PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.loading,
          message: 'Cruzando…',
        ),
      ),
      error: (error, _) => PulsoPanel(
        child: PulsoStateView(
          kind: PulsoStateKind.error,
          message:
              'No se pudo calcular el cruce.\n'
              '${statisticsErrorMessage(error)}',
          onRetry: () => ref.invalidate(segmentationProvider(consulta)),
        ),
      ),
      data: (data) => _Salida(
        data: data,
        consulta: consulta,
        monedas: monedas,
        compacto: compacto,
      ),
    );
  }
}

class _Salida extends ConsumerStatefulWidget {
  const _Salida({
    required this.data,
    required this.consulta,
    required this.monedas,
    required this.compacto,
  });

  final SegmentationResult data;
  final SegmentationQuery consulta;
  final List<CurrencyModel> monedas;
  final bool compacto;

  @override
  ConsumerState<_Salida> createState() => _SalidaState();
}

class _SalidaState extends ConsumerState<_Salida> {
  bool _exportando = false;

  /// Abre Clientes con el corte de esta fila ya puesto.
  ///
  /// Solo cuando la dimensión es del socio: un socio no tiene medio de pago ni
  /// moneda, así que esas filas no tienen conjunto de socios que enseñar.
  void _abrirClientes(ClientsAttribute atributo, SegmentationRow fila) {
    ref
        .read(clientsScopeFilterProvider.notifier)
        .showAttribute(
          attribute: atributo,
          value: fila.key,
          label: fila.label,
        );
    ref.read(dashboardNavProvider.notifier).setIndex(1);
  }

  Future<void> _exportar() async {
    setState(() => _exportando = true);
    try {
      final exportar = ref.read(segmentationExporterProvider);
      final resultado = await exportar(widget.consulta);
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            resultado.saved
                ? 'CSV con ${resultado.rows} fila(s) guardado.'
                : 'Descarga cancelada.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(statisticsErrorMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PulsoTokens.of(context);
    final data = widget.data;

    if (!data.compatible) {
      return PulsoPanel(
        key: const ValueKey('cruzador-incompatible'),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatsPanelTitle(
              '${data.measureTitle} por ${data.dimensionTitle.toLowerCase()}',
            ),
            const SizedBox(height: 8),
            Text(
              data.reason ?? 'Esta combinación no tiene sentido.',
              style: TextStyle(fontSize: 11, color: tokens.chalkDim),
            ),
            const SizedBox(height: 8),
            Text(
              'No se enseña un cero porque no se contó cero: no hay nada que '
              'contar.',
              style: TextStyle(fontSize: 9, color: tokens.muted),
            ),
          ],
        ),
      );
    }

    final formato = NumberFormat(data.money ? '#,##0.00' : '#,##0.##');
    final ancho = widget.compacto ? double.infinity : 440.0;
    // La fila lleva a Clientes solo si su eje es del socio. Con moneda, medio
    // de pago, cuenta o cobrador no hay conjunto de socios que enseñar, y con
    // `estado` haría falta reimplementar en Dart el corte que hace el SQL.
    final atributo = ClientsAttribute.fromDimension(data.dimension);
    final datosGrafico = [
      for (final fila in data.rows)
        PulsoChartDato(
          etiqueta: fila.label,
          valor: fila.value,
          nota: fila.denominator == null
              ? null
              : 'de ${formato.format(fila.denominator)}',
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PulsoPanel(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatsPanelTitle(
                '${data.measureTitle} por ${data.dimensionTitle.toLowerCase()}',
              ),
              const SizedBox(height: 4),
              Text(
                data.definition,
                key: const ValueKey('cruzador-definicion'),
                style: TextStyle(fontSize: 10, color: tokens.muted),
              ),
              const SizedBox(height: 6),
              Text(
                [
                  if (data.period.applies)
                    'Período ${data.period.from} → ${data.period.to}'
                  else
                    'Stock a día de hoy: el período no lo recorta',
                  if (data.currencyId != null)
                    nombreMoneda(widget.monedas, data.currencyId!),
                  if (data.total != null)
                    'total ${formato.format(data.total)}'
                  else
                    'sin total: no se suman medias',
                ].join(' · '),
                style: TextStyle(
                  fontFamily: PulsoFonts.mono,
                  fontSize: 9,
                  color: tokens.muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: ancho,
              child: PulsoPanel(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const StatsPanelTitle('Ranking'),
                    const SizedBox(height: 14),
                    PulsoBarras(
                      datos: datosGrafico,
                      mensajeVacio: 'No hay datos para este cruce.',
                      anchoEtiqueta: 140,
                    ),
                  ],
                ),
              ),
            ),
            // La dona solo cuenta participación, y una tasa no participa de
            // nada: sumar medias no da un todo.
            if (!data.rate && data.rows.isNotEmpty)
              SizedBox(
                width: ancho,
                child: PulsoPanel(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const StatsPanelTitle('Participación'),
                      const SizedBox(height: 14),
                      PulsoDona(
                        datos: datosGrafico.take(6).toList(growable: false),
                        centroTitulo: data.measureTitle.toUpperCase(),
                        centroValor: formato.format(data.total ?? 0),
                        mensajeVacio: 'No hay datos para este cruce.',
                      ),
                      if (data.rows.length > 6) ...[
                        const SizedBox(height: 8),
                        Text(
                          'La dona enseña las seis primeras; la tabla las '
                          '${data.rows.length}.',
                          style: TextStyle(fontSize: 9, color: tokens.muted),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        PulsoPanel(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(child: StatsPanelTitle('Tabla')),
                  Text(
                    '${data.rows.length} fila(s)',
                    style: TextStyle(
                      fontFamily: PulsoFonts.mono,
                      fontSize: 10,
                      color: tokens.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(height: 1, color: tokens.line),
              for (final fila in data.rows)
                _FilaTabla(
                  clave: fila.key,
                  onTap: atributo == null
                      ? null
                      : () => _abrirClientes(atributo, fila),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fila.label,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: tokens.chalk,
                              ),
                            ),
                            if (fila.denominator != null)
                              Text(
                                'sobre ${formato.format(fila.denominator)}'
                                '${fila.lowSample ? ' · muestra baja' : ''}',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: fila.lowSample
                                      ? tokens.warning
                                      : tokens.muted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (fila.share != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Text(
                            '${NumberFormat('#,##0.##').format(fila.share)}%',
                            style: TextStyle(
                              fontFamily: PulsoFonts.mono,
                              fontSize: 10,
                              color: tokens.muted,
                            ),
                          ),
                        ),
                      Text(
                        formato.format(fila.value),
                        style: TextStyle(
                          fontFamily: PulsoFonts.mono,
                          fontSize: 11,
                          color: tokens.chalk,
                        ),
                      ),
                      if (atributo != null) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward,
                          size: 13,
                          color: tokens.accent,
                        ),
                      ],
                    ],
                  ),
                ),
              if (data.rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    'Este cruce no devolvió ninguna fila en el período.',
                    style: TextStyle(fontSize: 11, color: tokens.muted),
                  ),
                ),
              const SizedBox(height: 12),
              PulsoSecondaryButton(
                label: _exportando ? 'Generando…' : 'Guardar CSV',
                icon: Icons.download,
                onPressed: _exportando ? null : _exportar,
              ),
              const SizedBox(height: 4),
              Text(
                atributo != null
                    ? 'Cada fila abre Clientes con ese corte ya puesto. El CSV '
                          'lleva el cruce completo con su definición, su '
                          'denominador y el motivo cuando no aplica.'
                    : 'Estas filas no abren Clientes: '
                          '${data.dimensionTitle.toLowerCase()} no es un dato '
                          'del socio, así que no hay un conjunto de socios que '
                          'enseñar. El CSV sí lleva el cruce completo.',
                style: TextStyle(fontSize: 9, color: tokens.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
