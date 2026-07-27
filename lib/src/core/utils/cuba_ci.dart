enum CubaCiSexo { masculino, femenino }

enum CubaCiEstado { vacio, incompleto, invalido, valido }

enum CubaCiErrorCodigo {
  caracteresNoNumericos,
  longitud,
  mesInvalido,
  diaInvalido,
  fechaInvalida,
  fechaFutura,
  edadFueraRango,
}

class CubaCiError {
  const CubaCiError(this.codigo, this.mensaje);

  final CubaCiErrorCodigo codigo;
  final String mensaje;
}

class CubaCiAnalisis {
  const CubaCiAnalisis({
    required this.raw,
    required this.normalizado,
    required this.estado,
    this.anio,
    this.mes,
    this.dia,
    this.siglo,
    this.fechaNacimiento,
    this.edad,
    this.sexoCodificado,
    this.errores = const [],
  });

  final String raw;
  final String normalizado;
  final CubaCiEstado estado;
  final int? anio;
  final int? mes;
  final int? dia;
  final String? siglo;
  final DateTime? fechaNacimiento;
  final int? edad;
  final CubaCiSexo? sexoCodificado;
  final List<CubaCiError> errores;

  bool get esCompleto => normalizado.length == 11;
  bool get esValido => estado == CubaCiEstado.valido;
}

CubaCiSexo? sexoDesdeDigito10(String digito) {
  if (!RegExp(r'^\d$').hasMatch(digito)) return null;
  return int.parse(digito).isEven ? CubaCiSexo.masculino : CubaCiSexo.femenino;
}

/// Analiza la estructura pública del número de identidad cubano.
///
/// El dígito 11 se conserva, pero no se intenta validar su checksum porque no
/// existe una fórmula pública verificable. [fechaReferencia] es una fecha de
/// calendario suministrada por la aplicación (en la zona del gimnasio); nunca
/// se consulta la zona o el reloj del dispositivo dentro de este módulo.
CubaCiAnalisis analizarCubaCi(
  String raw, {
  DateTime? fechaReferencia,
  int edadMaxima = 100,
}) {
  final value = raw.trim();
  if (value.isEmpty) {
    return CubaCiAnalisis(
      raw: raw,
      normalizado: value,
      estado: CubaCiEstado.vacio,
    );
  }

  if (!RegExp(r'^\d+$').hasMatch(value)) {
    return CubaCiAnalisis(
      raw: raw,
      normalizado: value,
      estado: CubaCiEstado.invalido,
      errores: const [
        CubaCiError(
          CubaCiErrorCodigo.caracteresNoNumericos,
          'El CI cubano se compone únicamente de dígitos.',
        ),
      ],
    );
  }

  if (value.length > 11) {
    return CubaCiAnalisis(
      raw: raw,
      normalizado: value,
      estado: CubaCiEstado.invalido,
      errores: const [
        CubaCiError(
          CubaCiErrorCodigo.longitud,
          'El CI cubano tiene exactamente 11 dígitos.',
        ),
      ],
    );
  }

  final errors = <CubaCiError>[];
  int? year;
  int? month;
  int? day;
  String? century;
  DateTime? birthDate;
  int? age;
  CubaCiSexo? encodedSex;

  if (value.length >= 4) {
    month = int.parse(value.substring(2, 4));
    if (month < 1 || month > 12) {
      errors.add(
        const CubaCiError(
          CubaCiErrorCodigo.mesInvalido,
          'Mes inválido: debe estar entre 01 y 12.',
        ),
      );
    }
  }

  if (value.length == 3 && int.parse(value[2]) > 1) {
    errors.add(
      const CubaCiError(
        CubaCiErrorCodigo.mesInvalido,
        'El primer dígito del mes debe ser 0 o 1.',
      ),
    );
  }

  if (value.length >= 6) {
    day = int.parse(value.substring(4, 6));
    if (day < 1 || day > 31) {
      errors.add(
        const CubaCiError(
          CubaCiErrorCodigo.diaInvalido,
          'Día inválido: debe estar entre 01 y 31.',
        ),
      );
    } else if (month != null &&
        month >= 1 &&
        month <= 12 &&
        day > _maximumPossibleDay(month)) {
      errors.add(
        CubaCiError(
          CubaCiErrorCodigo.diaInvalido,
          'Día inválido para el mes ${value.substring(2, 4)}.',
        ),
      );
    }
  }

  if (value.length == 5 && int.parse(value[4]) > 3) {
    errors.add(
      const CubaCiError(
        CubaCiErrorCodigo.diaInvalido,
        'El primer dígito del día debe estar entre 0 y 3.',
      ),
    );
  }

  if (value.length >= 7) {
    final yearInCentury = int.parse(value.substring(0, 2));
    final centuryDigit = value[6];
    if (centuryDigit == '9') {
      year = 1800 + yearInCentury;
      century = 'XIX';
    } else if (centuryDigit.compareTo('5') <= 0) {
      year = 1900 + yearInCentury;
      century = 'XX';
    } else {
      year = 2000 + yearInCentury;
      century = 'XXI';
    }

    if (month != null &&
        day != null &&
        month >= 1 &&
        month <= 12 &&
        day >= 1 &&
        day <= 31 &&
        errors.every(
          (error) =>
              error.codigo != CubaCiErrorCodigo.diaInvalido &&
              error.codigo != CubaCiErrorCodigo.mesInvalido,
        )) {
      final candidate = DateTime.utc(year, month, day);
      final exactDate =
          candidate.year == year &&
          candidate.month == month &&
          candidate.day == day;
      if (!exactDate) {
        errors.add(
          const CubaCiError(
            CubaCiErrorCodigo.fechaInvalida,
            'La fecha de nacimiento codificada no existe.',
          ),
        );
      } else {
        birthDate = candidate;
        if (fechaReferencia != null) {
          final referenceDay = DateTime.utc(
            fechaReferencia.year,
            fechaReferencia.month,
            fechaReferencia.day,
          );
          if (candidate.isAfter(referenceDay)) {
            errors.add(
              const CubaCiError(
                CubaCiErrorCodigo.fechaFutura,
                'La fecha de nacimiento codificada está en el futuro.',
              ),
            );
          } else {
            age = _ageOn(candidate, referenceDay);
            if (age > edadMaxima) {
              errors.add(
                CubaCiError(
                  CubaCiErrorCodigo.edadFueraRango,
                  'La fecha corresponde a una persona de $age años; '
                  'el máximo admitido es $edadMaxima.',
                ),
              );
            }
          }
        }
      }
    }
  }

  if (value.length >= 10) {
    encodedSex = sexoDesdeDigito10(value[9]);
  }

  final state = errors.isNotEmpty
      ? CubaCiEstado.invalido
      : value.length == 11
      ? CubaCiEstado.valido
      : CubaCiEstado.incompleto;

  return CubaCiAnalisis(
    raw: raw,
    normalizado: value,
    estado: state,
    anio: year,
    mes: month,
    dia: day,
    siglo: century,
    fechaNacimiento: birthDate,
    edad: age,
    sexoCodificado: encodedSex,
    errores: List.unmodifiable(errors),
  );
}

int _ageOn(DateTime birthDate, DateTime referenceDate) {
  var age = referenceDate.year - birthDate.year;
  final birthdayHasPassed =
      referenceDate.month > birthDate.month ||
      (referenceDate.month == birthDate.month &&
          referenceDate.day >= birthDate.day);
  if (!birthdayHasPassed) age -= 1;
  return age;
}

int _maximumPossibleDay(int month) {
  if (month == 2) return 29;
  if (month == 4 || month == 6 || month == 9 || month == 11) return 30;
  return 31;
}
