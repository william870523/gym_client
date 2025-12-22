import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'window_adapter.dart';

class WindowAdapterPlatform implements WindowAdapter {
  @override
  void init() {
    doWhenWindowReady(() {
      final win = appWindow;
      const initialSize = Size(1024, 768);
      win.minSize = const Size(800, 600);
      win.size = initialSize;
      win.alignment = Alignment.center;
      win.show();
    });
  }

  @override
  void setSize(double width, double height) {
    appWindow.size = Size(width, height);
  }

  @override
  void setTitle(String title) {
    appWindow.title = title;
  }
}

// Helper to check platform
bool get isDesktop => true;
