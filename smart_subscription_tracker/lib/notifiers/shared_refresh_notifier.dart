// shared_refresh_notifier.dart
import 'package:flutter/foundation.dart';

class RefreshNotifier extends ChangeNotifier {
  void triggerRefresh() {
    notifyListeners();
  }
}
