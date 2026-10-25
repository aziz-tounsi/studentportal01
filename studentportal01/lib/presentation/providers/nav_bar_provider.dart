import 'package:flutter_riverpod/flutter_riverpod.dart';

final navBarHiddenProvider = StateProvider<bool>((ref) => false);

/// Tracks when navigation originated from within the AI chat so that returning
/// from child screens (documents, emploi, absences, etc.) navigates back to AI chat.
final navigatedFromAIChatProvider = StateProvider<bool>((ref) => false);
