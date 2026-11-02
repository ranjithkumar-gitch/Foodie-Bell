import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../manager_session.dart';

/// Manager Code Management (spec §7.15): this Manager's code and territory.
/// The boundary map and change-request form are gone — neither existed on
/// the server (the form only showed a "submitted" message).
class ManagerCodeManagementScreen extends ConsumerStatefulWidget {
  const ManagerCodeManagementScreen({super.key});

  @override
  ConsumerState<ManagerCodeManagementScreen> createState() => _ManagerCodeManagementScreenState();
}

class _ManagerCodeManagementScreenState extends ConsumerState<ManagerCodeManagementScreen> {
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
          const SizedBox(height: 16),
          // No boundary map or change request here: neither exists on the
          // server yet. Boundary changes go through the Super Admin.
          Text('To change your territory boundary, contact the Super Admin through Help & Support.', style: TextStyle(color: palette.textSecondary, fontSize: 12.5)),
        ],
      ),
    );
  }
}
