import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardNavNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    state = index;
  }

  void reset() {
    state = 0;
  }
}

final dashboardNavProvider = NotifierProvider<DashboardNavNotifier, int>(
  DashboardNavNotifier.new,
);
