import 'package:fiveyear/data/entities.dart';
import 'package:fiveyear/data/objectbox.g.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:objectbox/objectbox.dart'; // Add this import for the Store class
import 'objectbox.g.dart'; // This will be generated

/// Provides access to the ObjectBox Store.
///
/// This class is created asynchronously and should be provided via a
/// FutureProvider.
class ObjectBox {
  /// The ObjectBox store.
  late final Store store;

  ObjectBox._create(this.store);

  /// Create an instance of ObjectBox to use throughout the app.
  static Future<ObjectBox> create() async {
    final docsDir = await getApplicationDocumentsDirectory();
    // Future<Store> openStore() is defined in the generated objectbox.g.dart
    final store = await openStore(directory: p.join(docsDir.path, "obx-db"));
    return ObjectBox._create(store);
  }
}
