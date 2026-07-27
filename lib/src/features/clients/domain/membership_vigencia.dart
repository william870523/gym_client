/// Vigencia de una membresía: si **hoy** cubre o ya no
/// (docs/DEMO_MEMBERSHIP_VIGENCIA.md).
///
/// **Espejo de `membership-vigencia.ts` de las dos APIs. Si cambia una, cambian
/// las tres**, o el escritorio y la web dirán cosas distintas del mismo socio.
///
/// Existe en el cliente porque no todas las pantallas leen del mismo endpoint:
/// la lista de socios recibe la vigencia ya derivada por el servidor
/// ([ClientModel.membershipVigencia]), pero el expediente trae el historial
/// completo de membresías y ahí solo viene el `estado` guardado. Cuando el
/// servidor la manda, **manda el servidor**; esta función es para el resto.
///
/// El problema que resuelve: `estado` admite `VENCIDA` pero **nadie lo escribe
/// nunca**. Se pone `ACTIVA` al activar y ahí se queda, así que una membresía
/// con la cobertura terminada seguía diciendo que estaba vigente.
library;

/// Vigencia derivada. No se guarda: se calcula al mostrar.
enum MembershipVigencia {
  /// Contratada y sin pagar: no cubre todavía, pero el socio existe.
  pendingPayment,

  /// Congelada por acuerdo: no consume días y no vence mientras dure.
  paused,

  /// Cubre hoy.
  current,

  /// La cobertura terminó, pero dentro de la ventana de cortesía.
  recentlyExpired,

  /// La cobertura terminó y ya pasó la ventana.
  expired,

  /// Dada de baja.
  cancelled,

  /// Sin membresía, o con un estado que no reconocemos.
  none,
}

/// Días naturales que una membresía vencida sigue contando como reciente.
///
/// Mismo número que usa el servidor y que la regla de asociados de un plan
/// (docs/PLAN_ASOCIADOS.md §5, decisión del dueño del 25-07-2026).
const int kMembershipRecentExpiryDays = 30;

/// Nombre que manda el servidor en `membresia_vigencia` para cada valor.
const Map<String, MembershipVigencia> _fromServer = {
  'PENDIENTE_PAGO': MembershipVigencia.pendingPayment,
  'PAUSADA': MembershipVigencia.paused,
  'VIGENTE': MembershipVigencia.current,
  'VENCIDA_RECIENTE': MembershipVigencia.recentlyExpired,
  'VENCIDA': MembershipVigencia.expired,
  'CANCELADA': MembershipVigencia.cancelled,
  'SIN_MEMBRESIA': MembershipVigencia.none,
};

/// Traduce el valor que manda el servidor. `null` si no lo reconoce, para que
/// quien llama pueda caer a [resolveMembershipVigencia] con un servidor viejo.
MembershipVigencia? membershipVigenciaFromServer(String? value) {
  final key = value?.trim().toUpperCase();
  if (key == null || key.isEmpty) return null;
  return _fromServer[key];
}

/// Deriva la vigencia a partir del estado guardado y la fecha de fin.
///
/// El orden importa: `CANCELADA` y `PAUSADA` mandan sobre la fecha —quien se
/// dio de baja no está vigente aunque su plan cubriera, y una pausa detiene el
/// reloj, así que su `fecha_fin` no significa nada mientras dure—.
///
/// [today] es la **fecha de negocio del gimnasio**, no la del dispositivo.
MembershipVigencia resolveMembershipVigencia({
  required String? status,
  required DateTime? endDate,
  required DateTime today,
}) {
  final estado = status?.trim().toUpperCase();
  if (estado == null || estado.isEmpty) return MembershipVigencia.none;
  if (estado == 'CANCELADA') return MembershipVigencia.cancelled;
  if (estado == 'PAUSADA') return MembershipVigencia.paused;
  if (estado == 'PENDIENTE_PAGO' || estado == 'PENDIENTE') {
    return MembershipVigencia.pendingPayment;
  }
  if (estado != 'ACTIVA' && estado != 'VENCIDA') {
    // Un estado desconocido no se interpreta como vigente: ante la duda sobre
    // quién entra, se falla cerrado.
    return MembershipVigencia.none;
  }
  if (endDate == null) return MembershipVigencia.current;

  final days = daysSinceExpiry(endDate, today);
  // El último día de cobertura todavía cubre.
  if (days <= 0) return MembershipVigencia.current;
  return days <= kMembershipRecentExpiryDays
      ? MembershipVigencia.recentlyExpired
      : MembershipVigencia.expired;
}

/// Días transcurridos desde que terminó la cobertura. Negativo si aún cubre,
/// que es lo que necesita un aviso de «por vencer».
int daysSinceExpiry(DateTime endDate, DateTime today) {
  final end = DateTime.utc(endDate.year, endDate.month, endDate.day);
  final day = DateTime.utc(today.year, today.month, today.day);
  return day.difference(end).inDays;
}

/// `true` solo si la membresía cubre hoy. Ni pausada ni vencida cubren.
bool coversToday(MembershipVigencia vigencia) =>
    vigencia == MembershipVigencia.current;

/// Etiqueta para pantalla.
String membershipVigenciaLabel(MembershipVigencia vigencia) =>
    switch (vigencia) {
      MembershipVigencia.current => 'Vigente',
      MembershipVigencia.recentlyExpired => 'Vencida hace poco',
      MembershipVigencia.expired => 'Vencida',
      MembershipVigencia.paused => 'Pausada',
      MembershipVigencia.pendingPayment => 'Pendiente de pago',
      MembershipVigencia.cancelled => 'Cancelada',
      MembershipVigencia.none => 'Sin membresía',
    };
