// lib/features/talk_with_bi/llm_chat_model.dart
import '../../core/services/llm_service.dart';
import 'bi_brain.dart';

/// Connects BiBrain to the on-device Gemma model (LiteRT-LM bridge).
class LlmChatModel implements ChatModel {
  LlmChatModel(this.llm);

  final LlmService llm;

  @override
  Future<void> start(String systemPrompt) => llm.startConversation(systemPrompt);

  @override
  Stream<String> send(String text) => llm.send(text);

  @override
  Future<void> cancel() => llm.cancel();
}
