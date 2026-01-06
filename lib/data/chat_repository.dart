import 'dart:async';
import 'package:fiveyear/data/entities.dart';
import 'package:fiveyear/data/objectbox.dart';
import 'package:fiveyear/objectbox.g.dart';

class ChatRepository {
  final ObjectBox _objectbox;
  late final StreamController<List<ChatEntity>> _chatController;

  ChatRepository(this._objectbox) {
    _chatController = StreamController<List<ChatEntity>>.broadcast(
      onListen: () {
        _emitHistory();
      },
    );
  }

  Box<ChatEntity> get _box => _objectbox.store.box<ChatEntity>();

  void _emitHistory() {
    final query = _box
        .query()
        .order(ChatEntity_.timestamp, flags: Order.descending)
        .build();
    final results = query.find();
    query.close();
    _chatController.add(results);
  }

  /// Watch chat history in real-time
  Stream<List<ChatEntity>> watchHistory() {
    return _chatController.stream;
  }

  /// Get all messages sorted by newest first (one-time fetch)
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
    _emitHistory(); // Trigger stream update
  }

  /// Clear database
  Future<void> clearHistory() async {
    _box.removeAll();
    _emitHistory(); // Trigger stream update
  }

  void dispose() {
    _chatController.close();
  }
}