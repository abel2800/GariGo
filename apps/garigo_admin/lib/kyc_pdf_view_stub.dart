import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Widget buildPdfFullscreen(String url) {
  return _PdfFallback(url: url);
}

class _PdfFallback extends StatelessWidget {
  const _PdfFallback({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf, size: 72, color: Colors.white70),
            const SizedBox(height: 16),
            const Text(
              'PDF preview is available on web. Open in a new tab to review.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () =>
                  launchUrl(Uri.parse(url), webOnlyWindowName: '_blank'),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open PDF'),
            ),
          ],
        ),
      ),
    );
  }
}
