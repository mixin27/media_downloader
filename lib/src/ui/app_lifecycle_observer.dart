import 'dart:async';
import 'dart:ui';

class AppLifecycleObserver {
  static final AppLifecycleObserver instance = AppLifecycleObserver._init();

  final StreamController<AppLifecycleState> _lifecycleController =
      StreamController<AppLifecycleState>.broadcast();

  Stream<AppLifecycleState> get lifecycleStream => _lifecycleController.stream;

  AppLifecycleState _currentState = AppLifecycleState.resumed;

  AppLifecycleObserver._init();

  AppLifecycleState get currentState => _currentState;
  bool get isInForeground => _currentState == AppLifecycleState.resumed;
  bool get isInBackground =>
      _currentState == AppLifecycleState.paused ||
      _currentState == AppLifecycleState.inactive ||
      _currentState == AppLifecycleState.detached;

  void onStateChanged(AppLifecycleState state) {
    if (_currentState != state) {
      _currentState = state;
      _lifecycleController.add(state);
    }
  }

  void dispose() {
    _lifecycleController.close();
  }
}
