import 'package:fiveyear/data/entities.dart';
import 'package:fiveyear/data/objectbox.dart';
import 'package:fiveyear/data/objectbox.g.dart';

class ChatRepository {
  final ObjectBox _objectbox;

  ChatRepository(this._objectbox);

  Box<ChatEntity> get _box => _objectbox.store.box<ChatEntity>();

  /// Get all messages sorted by newest first
  Future<List<ChatEntity>> getHistory() async {
    final query = _box
        .query()
        .order(ChatEntity_.timestamp, flags: Order.descending)
        .build();
    final results = query.find();
    query.close();
    return results;
  }

  /// Save a single message
  Future<void> saveMessage(String text, bool isUser) async {
    final message = ChatEntity()
      ..content = text
      ..isUser = isUser
      ..timestamp = DateTime.now();
    _box.put(message);
  }

  /// Clear database
  Future<void> clearHistory() async {
    _box.removeAll();
  }
}
