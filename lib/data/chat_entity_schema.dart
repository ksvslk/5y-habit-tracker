import 'package:isar/isar.dart';

part 'chat_entity_schema.g.dart';

@collection
class ChatEntity {
  Id id = Isar.autoIncrement;

  late String text;

  /// True if user sent it, False if AI sent it
  late bool isUser;

  @Index()
  late DateTime timestamp;
  
}