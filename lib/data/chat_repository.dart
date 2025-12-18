import 'package:fiveyear/data/chat_entity_schema.dart';
import 'package:isar/isar.dart';

class ChatRepository {
  final Future<Isar> _dbFuture;

  ChatRepository(this._dbFuture);

  /// Get all messages sorted by newest first
  Future<List<ChatEntity>> getHistory() async {
    final isar = await _dbFuture;
    // We sort by timestamp DESC so the newest message is first
    return await isar.chatEntitys.where().sortByTimestampDesc().findAll();
  }

  /// Save a single message
  Future<void> saveMessage(String text, bool isUser) async {
    final isar = await _dbFuture;
    final message = ChatEntity()
      ..text = text
      ..isUser = isUser
      ..timestamp = DateTime.now();

    await isar.writeTxn(() async {
      await isar.chatEntitys.put(message);
    });
  }

  /// Clear database
  Future<void> clearHistory() async {
    final isar = await _dbFuture;
    await isar.writeTxn(() async {
      await isar.chatEntitys.clear();
    });
  }
}