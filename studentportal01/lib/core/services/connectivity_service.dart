import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';

enum NetworkState {
  online,
  offlineNoInternet,
  offlineServerDown,
}

/// Service to monitor network connectivity and server reachability.
class ConnectivityService extends ChangeNotifier {
  static ConnectivityService? _instance;
  static ConnectivityService get instance => _instance ??= ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _periodicTimer;

  NetworkState _state = NetworkState.online;
  bool _isRecentlyRestored = false;
  bool _isChecking = false;
  DateTime? _lastOnlineTime;

  NetworkState get state => _state;
  bool get isOffline => _state != NetworkState.online;
  bool get isServerDown => _state == NetworkState.offlineServerDown;
  bool get isRecentlyRestored => _isRecentlyRestored;
  bool get isChecking => _isChecking;
  DateTime? get lastOnlineTime => _lastOnlineTime;

  ConnectivityService._() {
    _init();
  }

  void _init() {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _handleConnectivityResults(results);
    });

    // Initial check
    checkConnection();

    // Periodic check every 30 seconds
    _periodicTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      checkConnection();
    });
  }

  void _handleConnectivityResults(List<ConnectivityResult> results) {
    final hasConnection = results.any((r) => r != ConnectivityResult.none);
    if (!hasConnection) {
      _updateState(NetworkState.offlineNoInternet);
    } else {
      // Re-verify reachability to Supabase / Internet
      checkConnection();
    }
  }

  /// Actively tests connection to the server / internet
  Future<bool> checkConnection() async {
    if (_isChecking) return !isOffline;
    _isChecking = true;
    notifyListeners();

    try {
      final results = await _connectivity.checkConnectivity();
      final hasLocalConnection = results.any((r) => r != ConnectivityResult.none);

      if (!hasLocalConnection) {
        _updateState(NetworkState.offlineNoInternet);
        _isChecking = false;
        notifyListeners();
        return false;
      }

      // Check if Supabase host or public DNS is reachable
      final host = Uri.parse(SupabaseConfig.url).host;
      final lookup = await InternetAddress.lookup(host)
          .timeout(const Duration(seconds: 4));

      if (lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty) {
        _updateState(NetworkState.online);
        _lastOnlineTime = DateTime.now();
        _isChecking = false;
        notifyListeners();
        return true;
      } else {
        _updateState(NetworkState.offlineServerDown);
        _isChecking = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      // Lookup failed - try general internet lookup
      try {
        final internetLookup = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 3));
        if (internetLookup.isNotEmpty && internetLookup[0].rawAddress.isNotEmpty) {
          // Internet works, but Supabase host failed -> Server is down!
          _updateState(NetworkState.offlineServerDown);
        } else {
          _updateState(NetworkState.offlineNoInternet);
        }
      } catch (_) {
        _updateState(NetworkState.offlineNoInternet);
      }

      _isChecking = false;
      notifyListeners();
      return false;
    }
  }

  /// Call this when any Supabase or API call succeeds
  void reportNetworkSuccess() {
    if (_state != NetworkState.online) {
      _updateState(NetworkState.online);
    }
    _lastOnlineTime = DateTime.now();
  }

  /// Call this when an API call throws an error
  void reportNetworkError(dynamic error) {
    if (error == null) return;
    final errStr = error.toString().toLowerCase();

    final isServerDownIssue = errStr.contains('http status: 500') ||
        errStr.contains('http status: 502') ||
        errStr.contains('http status: 503') ||
        errStr.contains('http status: 504') ||
        errStr.contains('server error') ||
        errStr.contains('status code 5') ||
        errStr.contains('500 internal server error');

    final isClientOfflineIssue = errStr.contains('socketexception') ||
        errStr.contains('failed host lookup') ||
        errStr.contains('clientexception') ||
        errStr.contains('network is unreachable') ||
        errStr.contains('connection refused') ||
        errStr.contains('connection timed out') ||
        errStr.contains('timeoutexception') ||
        errStr.contains('handshakeexception');

    if (isServerDownIssue) {
      debugPrint('ConnectivityService: Server down error detected -> $error');
      _updateState(NetworkState.offlineServerDown);
    } else if (isClientOfflineIssue) {
      debugPrint('ConnectivityService: Network offline error detected -> $error');
      _updateState(NetworkState.offlineNoInternet);
    }
  }

  void _updateState(NetworkState newState) {
    if (_state == newState) return;

    final wasOffline = _state != NetworkState.online;
    _state = newState;

    if (wasOffline && newState == NetworkState.online) {
      _isRecentlyRestored = true;
      Timer(const Duration(milliseconds: 2600), () {
        _isRecentlyRestored = false;
        notifyListeners();
      });
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _periodicTimer?.cancel();
    super.dispose();
  }
}
