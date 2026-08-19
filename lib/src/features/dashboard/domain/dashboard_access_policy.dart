/// Defensa de navegación por permiso. La barra lateral solo orienta al
/// operador; esta política decide si un índice puede mostrarse incluso cuando
/// llega desde estado persistido, un enlace interno o una prueba.
bool dashboardIndexAllowed(int index, Set<String> permissions) {
  bool has(String permission) => permissions.contains(permission);
  bool any(Iterable<String> required) => required.any(has);

  switch (index) {
    case 0:
    case 8: // Apariencia no altera datos de negocio.
      return true;
    case 1:
    case 14:
    case 17:
      return any(['clientes.leer', 'entrenadores.gestionar']);
    case 3:
      return has('cobros.registrar');
    case 7:
    case 19:
      return has('clientes.escribir');
    case 20:
      return any(['tesoreria.cerrar', 'gastos.gobernar']);
    // M6 — cierre de la cadena. Aquí solo se comprueba el permiso, porque esta
    // política no conoce la sesión: quien de verdad decide es la **autoridad de
    // cadena**, y la comprueban las otras dos puertas —el menú, que solo se la
    // ofrece al Dueño, y el servidor, que responde 403 a cualquier otro—. El
    // permiso que se exige es el mismo con el que el concentrador protege
    // `/cierre-cadena`.
    case 37:
      return has('tesoreria.cerrar');
    case 22:
      return has('clientes.leer');
    case 23:
    case 26:
    case 35:
      return any(['tesoreria.cerrar', 'gastos.gobernar']);
    case 28:
    case 29:
    case 30:
    case 31:
    case 32:
    case 33:
    case 34:
    case 36:
      return has('estadisticas.leer');
    case 2:
    case 4:
    case 5:
    case 6:
    case 9:
    case 10:
    case 11:
    case 12:
    case 13:
    case 15:
    case 16:
    case 18:
    case 21:
    case 24:
    case 25:
    case 27:
      return has('configuracion.escribir');
    default:
      return false;
  }
}
