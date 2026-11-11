import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/connectivity_service.dart';

final connectivityServiceProvider = ChangeNotifierProvider<ConnectivityService>((ref) {
  return ConnectivityService.instance;
});

final isOfflineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityServiceProvider).isOffline;
});

final isServerDownProvider = Provider<bool>((ref) {
  return ref.watch(connectivityServiceProvider).isServerDown;
});

final networkStateProvider = Provider<NetworkState>((ref) {
  return ref.watch(connectivityServiceProvider).state;
});

final isRecentlyRestoredProvider = Provider<bool>((ref) {
  return ref.watch(connectivityServiceProvider).isRecentlyRestored;
});
