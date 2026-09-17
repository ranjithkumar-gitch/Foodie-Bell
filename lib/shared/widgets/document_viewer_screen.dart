import 'package:flutter/material.dart';

import 'app_network_image.dart';

/// Full-screen zoomable view of an uploaded document image — shared by the
/// Vendor's own checklist and the Manager's Vendor Detail screen, since both
/// just need to look at the same uploaded photo. Presented via `showDialog`
/// (`Dialog.fullscreen`) rather than a go_router route: this app has no bare
/// `Navigator.push` full-screen views anywhere, every transient view goes
/// through `showDialog`/`showModalBottomSheet`, so this stays consistent
/// without wiring a new route into three different role route files.
class DocumentViewerScreen extends StatelessWidget {
  const DocumentViewerScreen({super.key, required this.imageUrl, required this.title});

  final String imageUrl;
  final String title;

  static Future<void> show(BuildContext context, {required String imageUrl, required String title}) => showDialog(
    context: context,
    builder: (context) => DocumentViewerScreen(imageUrl: imageUrl, title: title),
  );

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: AppNetworkImage(url: imageUrl, fit: BoxFit.contain),
            ),
          ),
          SafeArea(
            child: AppBar(
              title: Text(title, style: const TextStyle(color: Colors.white)),
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
            ),
          ),
        ],
      ),
    );
  }
}
