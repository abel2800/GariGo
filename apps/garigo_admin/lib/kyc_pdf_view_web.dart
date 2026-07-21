import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

Widget buildPdfFullscreen(String url) {
  return _PdfIframe(url: url);
}

class _PdfIframe extends StatefulWidget {
  const _PdfIframe({required this.url});
  final String url;

  @override
  State<_PdfIframe> createState() => _PdfIframeState();
}

class _PdfIframeState extends State<_PdfIframe> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType =
        'garigo-kyc-pdf-${widget.url.hashCode}-${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = widget.url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      iframe.setAttribute('allowfullscreen', 'true');
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
