import 'assistant_intent.dart';

/// Abstract contract for parsing voice transcripts or typed queries into structured intents.
abstract class IntentParser {
  /// Parses the input [text] into an [AssistantIntent].
  /// [referenceNow] can be supplied for deterministic testing or custom reference dates.
  AssistantIntent parse(String text, {DateTime? referenceNow});
}
