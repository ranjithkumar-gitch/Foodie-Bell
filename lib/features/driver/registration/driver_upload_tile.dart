import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';

/// Document/photo upload affordance shared by the Vehicle & Documents
/// registration steps — picks an image via [ImagePicker] and shows the
/// picked filename as proof of "upload". There's no real storage backend or
/// liveness detection here (spec explicitly allows a plain camera capture to
/// stand in for the selfie/liveness step); this is scaffolding only.
class DriverUploadTile extends StatelessWidget {
  const DriverUploadTile({
    super.key,
    required this.label,
    required this.fileName,
    required this.onPicked,
    this.icon = Icons.upload_file_rounded,
    this.source = ImageSource.gallery,
  });

  final String label;
  final String? fileName;
  final ValueChanged<String> onPicked;
  final IconData icon;
  final ImageSource source;

  Future<void> _pick() async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 70);
    if (picked != null) onPicked(picked.name);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final done = fileName != null;
    return InkWell(
      onTap: _pick,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: done ? palette.primaryLight.withValues(alpha: 0.14) : palette.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: done ? palette.primary : palette.border),
        ),
        child: Row(
          children: [
            Icon(done ? Icons.check_circle_rounded : icon, color: done ? palette.primary : palette.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: palette.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    done ? fileName! : 'Tap to upload',
                    style: TextStyle(fontSize: 12.5, color: done ? palette.primary : palette.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: palette.textMuted),
          ],
        ),
      ),
    );
  }
}
