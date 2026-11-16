import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

/// Reusable helper to download or view files across Documents, Announcements, and Suggestions
class FileDownloadHelper {
  static Future<void> downloadFile({
    required BuildContext context,
    required String url,
    required String fileName,
  }) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return;

    // Show initial feedback
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Téléchargement de $fileName...',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        duration: const Duration(minutes: 5),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: const StadiumBorder(),
      ),
    );

    try {
      if (kIsWeb) {
        await launchUrl(Uri.parse(cleanUrl), mode: LaunchMode.externalApplication);
        return;
      }

      final response = await http.get(Uri.parse(cleanUrl));
      if (response.statusCode == 200) {
        Directory? targetDir;
        if (Platform.isAndroid) {
          final downloadDir = Directory('/storage/emulated/0/Download');
          if (await downloadDir.exists()) {
            targetDir = downloadDir;
          } else {
            targetDir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
          }
        } else {
          targetDir = await getApplicationDocumentsDirectory();
        }

        // Clean file name
        final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        final filePath = '${targetDir.path}/$safeName';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        if (context.mounted) {
          final messenger = ScaffoldMessenger.of(context);
          messenger.removeCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Fichier téléchargé : $safeName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              duration: const Duration(seconds: 3),
              shape: const StadiumBorder(),
              action: SnackBarAction(
                label: 'Ouvrir',
                textColor: Colors.white,
                onPressed: () {
                  messenger.hideCurrentSnackBar();
                  OpenFilex.open(filePath);
                },
              ),
            ),
          );
          // Explicitly dismiss after 3 seconds to ensure it never stays stuck
          Future.delayed(const Duration(seconds: 3), () {
            try {
              messenger.hideCurrentSnackBar();
            } catch (_) {}
          });
        }
      } else {
        await launchUrl(Uri.parse(cleanUrl), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Direct download error: $e');
      try {
        await launchUrl(Uri.parse(cleanUrl), mode: LaunchMode.externalApplication);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Impossible de télécharger ce fichier'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: const StadiumBorder(),
            ),
          );
        }
      }
    }
  }

  static Future<void> viewFile({
    required BuildContext context,
    required String url,
    String? fileName,
  }) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return;
    try {
      final uri = Uri.parse(cleanUrl);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      try {
        await launchUrl(Uri.parse(cleanUrl), mode: LaunchMode.platformDefault);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Impossible d\'ouvrir ce fichier'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: const StadiumBorder(),
            ),
          );
        }
      }
    }
  }
}
