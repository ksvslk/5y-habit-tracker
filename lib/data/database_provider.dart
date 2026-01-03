import 'package:fiveyear/data/objectbox.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides the ObjectBox store instance to the rest of the app.
/// 
/// It's a FutureProvider because opening the store is an async operation.
/// Other providers will watch this to get the store when it's ready.
final objectboxProvider = FutureProvider<ObjectBox>((ref) async {
  return ObjectBox.create();
});
