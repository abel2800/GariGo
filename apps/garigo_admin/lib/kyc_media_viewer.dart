import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'kyc_pdf_view_stub.dart'
    if (dart.library.html) 'kyc_pdf_view_web.dart' as pdf_view;

Future<void> openKycMediaFullscreen(
  BuildContext context, {
  required String url,
  String title = 'Document',
  required bool isPdf,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: true,
      barrierDismissible: false,
      pageBuilder: (_, __, ___) => KycMediaViewerPage(
        url: url,
        title: title,
        isPdf: isPdf,
      ),
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

class KycMediaViewerPage extends StatelessWidget {
  const KycMediaViewerPage({
    super.key,
    required this.url,
    required this.title,
    required this.isPdf,
  });

  final String url;
  final String title;
  final bool isPdf;

  void _close(BuildContext context) {
    final nav = Navigator.of(context, rootNavigator: true);
    if (nav.canPop()) {
      nav.pop();
    }
  }

  Future<void> _openExternal() async {
    await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () => _close(context),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: isPdf
                      ? pdf_view.buildPdfFullscreen(url)
                      : InteractiveViewer(
                          minScale: 0.4,
                          maxScale: 8,
                          child: Center(
                            child: Image.network(
                              url,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'Could not load image',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
                // Top bar with title + clear X to leave fullscreen
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.72),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Open in new tab',
                              onPressed: _openExternal,
                              icon: const Icon(
                                Icons.open_in_new,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Material(
                              color: Colors.white,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => _close(context),
                                child: const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.black,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
