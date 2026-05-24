import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

import '../core/utils/app_logger.dart';

/// Listens to platform connectivity changes and validates that we actually
/// have an internet route by pinging a small set of reliable endpoints.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService({
    Connectivity? connectivity,
    InternetConnection? checker,
  })  : _connectivity = connectivity ?? Connectivity(),
        _checker = checker ?? InternetConnection();

  final Connectivity _connectivity;
  final InternetConnection _checker;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<InternetStatus>? _statusSub;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Future<void> init() async {
    final initial = await _connectivity.checkConnectivity();
    await _refresh(initial);

    _connectivitySub = _connectivity.onConnectivityChanged.listen(_refresh);
    _statusSub = _checker.onStatusChange.listen((status) {
      final online = status == InternetStatus.connected;
      _setOnline(online);
    });
  }

  Future<void> _refresh(List<ConnectivityResult> results) async {
    final hasInterface = results.any((r) => r != ConnectivityResult.none);
    if (!hasInterface) {
      _setOnline(false);
      return;
    }
    try {
      final hasInternet = await _checker.hasInternetAccess;
      _setOnline(hasInternet);
    } catch (e, s) {
      AppLogger.w('Connectivity check failed', e, s);
      _setOnline(false);
    }
  }

  /// Force-recheck. Useful for retry buttons on the offline screen.
  Future<bool> recheck() async {
    final results = await _connectivity.checkConnectivity();
    await _refresh(results);
    return _isOnline;
  }

  void _setOnline(bool value) {
    if (_isOnline == value) return;
    _isOnline = value;
    AppLogger.i('Connectivity: ${value ? "online" : "offline"}');
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }
}
