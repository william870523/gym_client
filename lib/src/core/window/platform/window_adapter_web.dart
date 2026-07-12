import 'package:flutter/foundation.dart';

import 'window_adapter.dart';

class WindowAdapterPlatform implements WindowAdapter {
  @override
  void init() {
    if (kDebugMode) {
      debugPrint('WindowAdapter: Web Init (No-op)');
    }
  }

  @override
  void setSize(double width, double height) {
    // Browser handles size
  }

  @override
  void setTitle(String title) {
    // Browser handles title
  }
}

bool get isDesktop => false;
