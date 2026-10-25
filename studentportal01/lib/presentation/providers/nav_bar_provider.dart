import 'package:flutter_riverpod/flutter_riverpod.dart';

final navBarHiddenProvider = StateProvider<bool>((ref) => false);

/// Tracks when navigation originated from within the AI chat so that returning
/// from child screens (documents, emploi, absences, etc.) navigates back to AI chat.
final navigatedFromAIChatProvider = StateProvider<bool>((ref) => false);

/// Interceptor callback for edge back swipes. If returns true, the swipe was consumed
/// (e.g. closing an active search bar or drawer) and the page navigation should not exit.
final backSwipeInterceptorProvider = StateProvider<bool Function()?>((ref) => null);

/// Tracks whether the side drawer was open when navigating to side-nav pages
/// (/profile, /settings, /contact, /about, /mon-solde) so that sliding back reveals the drawer open.
final sideDrawerOpenProvider = StateProvider<bool>((ref) => false);
