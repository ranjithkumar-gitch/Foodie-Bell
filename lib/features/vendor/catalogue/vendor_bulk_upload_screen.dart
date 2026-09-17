import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Bulk Catalogue Upload (spec §5.12, lower priority): a "Upload CSV"
/// button that simulates a file pick + upload and shows a fake success
/// toast — no real file parsing or backend, per the mock-only constraint.
class VendorBulkUploadScreen extends StatefulWidget {
  const VendorBulkUploadScreen({super.key});

  @override
  State<VendorBulkUploadScreen> createState() => _VendorBulkUploadScreenState();
}

class _VendorBulkUploadScreenState extends State<VendorBulkUploadScreen> {
  bool _uploading = false;

  Future<void> _upload() async {
    setState(() => _uploading = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() => _uploading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('catalogue_upload.csv uploaded — 24 products updated.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Bulk Catalogue Upload')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: palette.border, style: BorderStyle.solid)),
              child: Column(
                children: [
                  Icon(Icons.upload_file_rounded, size: 44, color: palette.primary),
                  const SizedBox(height: 14),
                  Text('Upload a CSV of your full product list to add or update many products at once.', textAlign: TextAlign.center, style: TextStyle(color: palette.textSecondary)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _uploading ? null : _upload,
                    icon: _uploading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4))
                        : const Icon(Icons.file_upload_outlined),
                    label: Text(_uploading ? 'Uploading...' : 'Upload CSV'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: palette.surfaceMuted, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(Icons.description_outlined, color: palette.textSecondary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Expected columns: name, description, price, unit, sub_category, veg, in_stock.',
                      style: TextStyle(fontSize: 12, color: palette.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
