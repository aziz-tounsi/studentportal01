import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();
  static const String _prefKey = 'biometric_lock_enabled';

  /// Check if the device hardware supports biometrics (Face ID, Touch ID, Fingerprint)
  Future<bool> isBiometricsAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } on PlatformException catch (e) {
      debugPrint('[BiometricService] isBiometricsAvailable error: $e');
      return false;
    }
  }

  /// Get list of available biometric types on device
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      debugPrint('[BiometricService] getAvailableBiometrics error: $e');
      return [];
    }
  }

  /// Check if biometric lock is enabled in user settings
  Future<bool> isBiometricLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  /// Save biometric lock setting
  Future<void> setBiometricLockEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enabled);
  }

  /// Trigger real biometric prompt (Face ID / Touch ID / Fingerprint)
  Future<bool> authenticate({String? reason}) async {
    try {
      final available = await isBiometricsAvailable();
      if (!available) {
        debugPrint('[BiometricService] Biometrics not available on this device');
        return false;
      }

      return await _auth.authenticate(
        localizedReason: reason ?? 'Authentifiez-vous pour accéder à votre espace élève',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException catch (e) {
      debugPrint('[BiometricService] Authentication error: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[BiometricService] Unknown authentication error: $e');
      return false;
    }
  }
}
