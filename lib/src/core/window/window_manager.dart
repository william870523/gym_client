export 'platform/window_adapter.dart';

import 'platform/window_adapter.dart';
import 'platform/window_adapter_web.dart'
    if (dart.library.io) 'platform/window_adapter_desktop.dart';

final WindowAdapter windowManager = WindowAdapterPlatform();
final bool isDesktopPlatform = isDesktop; // Exposed global getter
