# 📱 gym_client

Aplicación cliente para el ecosistema de gestión de gimnasios (PAM). Desarrollada en Flutter, diseñada para funcionar principalmente en **Desktop (Windows)** y **Web**.

## 🚀 Visión General

Esta aplicación es la interfaz de usuario para el `gym-local-api`. Permite a los recepcionistas y administradores gestionar el gimnasio diariamente. Se conecta exclusivamente al `gym-local-api` (localhost), garantizando funcionalidad offline.

### Módulos Principales (`src/features`)
- **🔐 Auth**: Login local y manejo de sesiones.
- **📊 Dashboard**: Vista general de estadísticas y estado del sistema.
- **👥 Clients**: Gestión completa de clientes (Altas, Bajas, Edición).
- **💰 Financials**: Registro de pagos, membresías y control de caja.
- **🏢 Gyms**: Configuración de la sucursal actual.
- **👤 Users**: Gestión de usuarios operadores.

## 🛠️ Tecnologías

- **Framework**: Flutter
- **Arquitectura**: Clean Architecture (capas de Presentación, Dominio, Datos).
- **State Management**: Riverpod (v2.x)
- **Routing**: GoRouter
- **Localization**: `flutter_localizations` (Soporte i18n).

## ⚙️ Configuración y Ejecución

### Prerequisitos
- Flutter SDK (Stable channel)
- `gym-local-api` ejecutándose en `localhost:8081` (o puerto configurado).

### Instalación

```bash
# Obtener dependencias
flutter pub get
```

### Ejecutar

**Desktop (Windows)**:
Recomendado para producción en sucursales.
```bash
flutter run -d windows
```

**Web**:
```bash
flutter run -d chrome
```

## 🏗️ Estructura del Proyecto

```
lib/src/
├── core/           # Utilidades, config, temas, router central
├── features/       # Módulos funcionales (Clean Arch dentro de cada uno)
│   ├── auth/
│   ├── clients/
│   └── ...
├── l10n/           # Archivos de localización (.arb)
└── main.dart       # Punto de entrada
```
