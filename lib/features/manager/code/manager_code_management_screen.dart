import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/mock_map_view.dart';
import '../manager_session.dart';

/// Manager Code Management (spec §7.15) — view the code + territory
/// boundary, and a boundary-edit-request form that just shows a "submitted
/// for Admin review" confirmation (no shared provider to actually route
/// this to Admin in the demo).
class ManagerCodeManagementScreen extends ConsumerStatefulWidget {
  const ManagerCodeManagementScreen({super.key});

  @override
  ConsumerState<ManagerCodeManagementScreen> createState() => _ManagerCodeManagementScreenState();
}

class _ManagerCodeManagementScreenState extends ConsumerState<ManagerCodeManagementScreen> {
  final _requestController = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _requestController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_requestController.text.trim().isEmpty) return;
    setState(() => _submitted = true);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final managerAccount = ref.watch(currentManagerAccountProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Manager Code Management')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: LinearGradient(colors: palette.promoGradient), borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MANAGER CODE', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
                const SizedBox(height: 8),
                Text(managerAccount.managerCode ?? '—', style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Colors.white)),
                const SizedBox(height: 6),
                Text(managerAccount.territory ?? '—', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Territory boundary', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          MockMapView(height: 200, borderRadius: BorderRadius.circular(16)),
          const SizedBox(height: 24),
          Text('Request a boundary change', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text('Describe the change — it will be sent to Admin for review.', style: TextStyle(color: palette.textSecondary, fontSize: 12.5)),
          const SizedBox(height: 12),
          TextField(
            controller: _requestController,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'e.g. Add pincode 500084 to my territory'),
          ),
          const SizedBox(height: 14),
          ElevatedButton(onPressed: _submit, child: const Text('Submit request')),
          if (_submitted) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: palette.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: palette.success),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Submitted for Admin review.', style: TextStyle(color: palette.success, fontWeight: FontWeight.w700))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
