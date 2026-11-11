import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Translates any raw exception, Supabase/Postgrest/Storage/Auth error, or
/// technical failure into a clear, non-technical English message for end users.
class UserFriendlyError {
  UserFriendlyError._();

  static String format(
    Object? error, {
    String? fallback,
    String? actionContext,
  }) {
    final defaultMsg = fallback ??
        (actionContext != null
            ? 'Unable to $actionContext right now. Please try again.'
            : 'Something went wrong while processing your request. Please try again.');

    if (error == null) return defaultMsg;

    if (error is TimeoutException) {
      return 'The request took too long to respond. Please check your internet connection and try again.';
    }

    if (error is PostgrestException) {
      return _fromPostgrest(error, defaultMsg);
    }

    if (error is StorageException) {
      return _fromStorage(error, defaultMsg);
    }

    if (error is AuthException) {
      return _fromAuth(error, defaultMsg);
    }

    if (error is FunctionException) {
      return _fromRawString(
        '${error.reasonPhrase ?? ''} ${error.details ?? ''} status:${error.status}',
        defaultMsg,
      );
    }

    return _fromRawString(error.toString(), defaultMsg);
  }

  static String _fromPostgrest(PostgrestException error, String defaultMsg) {
    final code = error.code?.trim().toUpperCase() ?? '';
    final lower = '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
        .toLowerCase();

    if (code == '42501' ||
        lower.contains('row-level security') ||
        lower.contains('permission denied') ||
        lower.contains('insufficient privilege')) {
      return 'You do not have permission to perform this action. Please contact your administrator.';
    }

    if (code == '23505' ||
        lower.contains('duplicate key') ||
        lower.contains('unique constraint') ||
        lower.contains('already exists')) {
      if (lower.contains('email')) {
        return 'An account with this email address already exists.';
      }
      if (lower.contains('code')) {
        return 'This code is already in use. Please enter a different one.';
      }
      return 'A matching record already exists. Please use different details and try again.';
    }

    if (code == '23503' ||
        lower.contains('foreign key') ||
        lower.contains('still referenced') ||
        lower.contains('violates foreign key')) {
      return 'This item cannot be modified or deleted because it is linked to existing records.';
    }

    if (code == '23502' ||
        lower.contains('not-null constraint') ||
        lower.contains('null value in column')) {
      return 'Some required information is missing. Please fill in all required fields.';
    }

    if (code == '22P02' || lower.contains('invalid input syntax')) {
      return 'One or more entered values are not in the valid format. Please review your input.';
    }

    if (code == 'PGRST116' || lower.contains('0 rows')) {
      return 'The requested item could not be found. It may have been removed or updated.';
    }

    if (code.startsWith('PGRST') ||
        lower.contains('schema cache') ||
        lower.contains('could not find')) {
      return 'We could not complete this action due to a server configuration issue. Please contact support.';
    }

    return _fromRawString(error.message, defaultMsg);
  }

  static String _fromStorage(StorageException error, String defaultMsg) {
    final status = error.statusCode?.trim() ?? '';
    final lower = '${error.message} ${error.error ?? ''}'.toLowerCase();

    if (status == '404' ||
        lower.contains('bucket not found') ||
        lower.contains('nosuchbucket')) {
      return 'File storage is not available right now. Please contact your administrator.';
    }

    if (status == '413' ||
        lower.contains('too large') ||
        lower.contains('maximum allowed size') ||
        lower.contains('file size')) {
      return 'This file is too large to upload. Please select a smaller file and try again.';
    }

    if (status == '415' ||
        lower.contains('mime') ||
        lower.contains('file type') ||
        lower.contains('invalid key')) {
      return 'This file format or filename is not supported. Please upload a valid file.';
    }

    if (status == '403' ||
        status == '401' ||
        lower.contains('row-level security') ||
        lower.contains('policy') ||
        lower.contains('unauthorized') ||
        lower.contains('permission')) {
      return 'You do not have permission to upload or manage files here. Please contact your administrator.';
    }

    return 'Unable to upload the file right now. Please try again.';
  }

  static String _fromAuth(AuthException error, String defaultMsg) {
    final lower = error.message.toLowerCase();

    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid_credentials') ||
        lower.contains('invalid email or password') ||
        lower.contains('invalid password')) {
      return 'Incorrect email or password. Please check your credentials and try again.';
    }

    if (lower.contains('email not confirmed') ||
        lower.contains('email_not_confirmed')) {
      return 'This email address has not been confirmed yet. Please check your inbox.';
    }

    if (lower.contains('user already registered') ||
        lower.contains('already registered') ||
        lower.contains('already exists')) {
      return 'An account with this email address already exists.';
    }

    if (lower.contains('weak password') ||
        lower.contains('password should be')) {
      return 'The password is too weak. Please choose a stronger password.';
    }

    if (lower.contains('rate limit') ||
        lower.contains('too many requests') ||
        lower.contains('over_email_send_rate_limit')) {
      return 'Too many attempts right now. Please wait a moment and try again.';
    }

    if (lower.contains('jwt') ||
        lower.contains('token') ||
        lower.contains('session') ||
        lower.contains('expired')) {
      return 'Your session has expired. Please sign in again to continue.';
    }

    return 'Authentication failed. Please verify your details and try again.';
  }

  static String _fromRawString(String raw, String defaultMsg) {
    final lower = raw.toLowerCase();

    if (lower.contains('socketexception') ||
        lower.contains('clientexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('xmlhttprequest') ||
        lower.contains('network error') ||
        lower.contains('failed to fetch') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('connection closed') ||
        lower.contains('no internet') ||
        lower.contains('offline') ||
        lower.contains('timed out') ||
        lower.contains('timeout')) {
      return 'Unable to connect to the server. Please check your internet connection and try again.';
    }

    if (lower.contains('42501') ||
        lower.contains('row-level security') ||
        lower.contains('permission denied') ||
        lower.contains('permissions') ||
        lower.contains('refusée') ||
        lower.contains('accès refusé') ||
        lower.contains('non autoris') ||
        lower.contains('super admin') ||
        lower.contains('forbidden') ||
        lower.contains('access denied') ||
        lower.contains('insufficient privilege') ||
        lower.contains('not authorized') ||
        lower.contains('unauthorized') ||
        lower.contains('403')) {
      return 'You do not have permission to perform this action. Please contact your administrator.';
    }

    if (lower.contains('chevauch') || lower.contains('overlap')) {
      return 'The selected dates overlap with an existing period. Please choose different dates.';
    }

    if (lower.contains('date de début') ||
        lower.contains('strictement antérieure')) {
      return 'The start date must be earlier than the end date.';
    }

    if (lower.contains('comprise dans') || lower.contains('limites de l\'année')) {
      return 'The selected dates must fall within the active academic year.';
    }

    if (lower.contains('aucune année scolaire')) {
      return 'No active academic year was found. Please configure one first.';
    }

    if (lower.contains('jwt') ||
        lower.contains('refresh_token') ||
        lower.contains('invalid or expired token') ||
        lower.contains('session expired') ||
        lower.contains('non connecte') ||
        lower.contains('non connecté') ||
        lower.contains('not logged in') ||
        lower.contains('not authenticated') ||
        lower.contains('401')) {
      return 'Your session has expired. Please sign in again to continue.';
    }

    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid_credentials') ||
        lower.contains('invalid email or password') ||
        lower.contains('incorrect email or password') ||
        lower.contains('invalid password')) {
      return 'Incorrect email or password. Please check your credentials and try again.';
    }

    if (lower.contains('email not confirmed') ||
        lower.contains('email_not_confirmed') ||
        lower.contains('not been confirmed yet')) {
      return 'This email address has not been confirmed yet. Please check your inbox.';
    }

    if (lower.contains('bucket not found') ||
        lower.contains('nosuchbucket') ||
        lower.contains('no storage') ||
        lower.contains('aucun espace de stockage') ||
        lower.contains('file storage is') ||
        (lower.contains('bucket') &&
            (lower.contains('introuvable') || lower.contains('not found')))) {
      return 'File storage is currently unavailable. Please contact your administrator.';
    }

    if (lower.contains('23505') ||
        lower.contains('duplicate key') ||
        lower.contains('unique constraint') ||
        lower.contains('already exists') ||
        lower.contains('existe déjà') ||
        lower.contains('409')) {
      return 'A matching record already exists. Please use different details and try again.';
    }

    if (lower.contains('23503') ||
        lower.contains('foreign key') ||
        lower.contains('still referenced')) {
      return 'This item cannot be modified or removed because it is linked to other records.';
    }

    if (lower.contains('23502') || lower.contains('not-null constraint')) {
      return 'Some required information is missing. Please complete all required fields.';
    }

    if (lower.contains('too large') ||
        lower.contains('file size') ||
        lower.contains('413')) {
      return 'The selected file is too large. Please choose a smaller file and try again.';
    }

    if (lower.contains('mime') ||
        lower.contains('unsupported') ||
        lower.contains('415')) {
      return 'This file format is not supported. Please select a valid file.';
    }

    if (lower.contains('too many requests') ||
        lower.contains('rate limit') ||
        lower.contains('429')) {
      return 'Too many requests in a short time. Please wait a moment and try again.';
    }

    if (lower.contains('not found') ||
        lower.contains('introuvable') ||
        lower.contains('pgrst116') ||
        lower.contains('404')) {
      return 'The requested item could not be found. Please refresh the page and try again.';
    }

    if (lower.contains('500') ||
        lower.contains('502') ||
        lower.contains('503') ||
        lower.contains('504') ||
        lower.contains('internal server error') ||
        lower.contains('service unavailable')) {
      return 'The server is temporarily unavailable. Please try again in a moment.';
    }

    if (lower.contains('formatexception') ||
        lower.contains('invalid json') ||
        lower.contains('unexpected character') ||
        lower.contains('parse')) {
      return 'The data or file format could not be read. Please verify the file and try again.';
    }

    return defaultMsg;
  }
}
