import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

// Subscription Service Provider
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService();
});

// Subscription Status Provider - watches for changes
final subscriptionStatusProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(subscriptionServiceProvider);
  return service.subscriptionStatusStream;
});

// Customer Info Provider - for detailed subscription data
final customerInfoProvider = FutureProvider<CustomerInfo?>((ref) async {
  final service = ref.watch(subscriptionServiceProvider);
  return await service.getCustomerInfo();
});

class SubscriptionService {
  static const String _entitlementId = '5Y Pro';

  // Stream controller for subscription status changes
  final _statusStreamController = StreamController<bool>.broadcast();

  Stream<bool> get subscriptionStatusStream => _statusStreamController.stream;

  SubscriptionService() {
    _initialize();
  }

  Future<void> _initialize() async {
    // Listen to purchase updates from RevenueCat
    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      final hasEntitlement = _checkEntitlement(customerInfo);
      _statusStreamController.add(hasEntitlement);
    });

    // Get initial status
    final customerInfo = await getCustomerInfo();
    if (customerInfo != null) {
      final hasEntitlement = _checkEntitlement(customerInfo);
      _statusStreamController.add(hasEntitlement);
    }
  }

  /// Check if user has the Pro entitlement
  Future<bool> hasProEntitlement() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return _checkEntitlement(customerInfo);
    } catch (e) {
      print('Error checking entitlement: $e');
      return false;
    }
  }

  /// Get customer info
  Future<CustomerInfo?> getCustomerInfo() async {
    try {
      return await Purchases.getCustomerInfo();
    } catch (e) {
      print('Error getting customer info: $e');
      return null;
    }
  }

  /// Check entitlement from CustomerInfo
  bool _checkEntitlement(CustomerInfo customerInfo) {
    return customerInfo.entitlements.active.containsKey(_entitlementId);
  }

  /// Get subscription expiry date if active
  String? getExpiryDate(CustomerInfo customerInfo) {
    final entitlement = customerInfo.entitlements.active[_entitlementId];
    return entitlement?.expirationDate;
  }

  /// Check if subscription will renew
  bool willRenew(CustomerInfo customerInfo) {
    final entitlement = customerInfo.entitlements.active[_entitlementId];
    return entitlement?.willRenew ?? false;
  }

  void dispose() {
    _statusStreamController.close();
  }
}
