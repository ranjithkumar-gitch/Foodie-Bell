import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/account.dart';
import 'session_controller.dart';

/// What the signed-in account may see: the same role / accountId /
/// territoryId the server puts in its custom claims, which `firestore.rules`
/// enforces. Providers build their queries from this so they only ever ask
/// for documents the rules allow — rules aren't filters, so an unscoped
/// query (say, every order) is refused outright even when the app would
/// only have shown its own rows.
class AccessScope {
  const AccessScope({
    required this.role,
    required this.accountId,
    required this.isActive,
    this.territoryId,
  });

  final AppRole role;
  final String accountId;
  final String? territoryId;

  /// Approved and not suspended — mirrors the `active` claim. Some queries
  /// (a Driver's open offers) are only allowed then.
  final bool isActive;
}

/// Null while signed out. Only changes when the role, account, territory or
/// approval does, so providers watching it don't re-query on every
/// unrelated session update.
final accessScopeProvider = Provider<AccessScope?>((ref) {
  final (role, accountId, territoryId, stage) = ref.watch(
    sessionControllerProvider.select((s) => (s.role, s.account?.id, s.account?.territoryId, s.stage)),
  );
  if (role == null || accountId == null || stage == AuthStage.unauthenticated) return null;
  return AccessScope(
    role: role,
    accountId: accountId,
    territoryId: territoryId,
    isActive: stage == AuthStage.active,
  );
});

/// Combines several live query results into one list, de-duplicated by
/// [idOf] — for a role whose allowed documents need more than one query (a
/// Driver's own deliveries plus open offers; a Manager's tickets raised and
/// received). Emits once every query has delivered its first result.
Stream<List<T>> mergeQueryStreams<T>(List<Stream<List<T>>> streams, String Function(T) idOf) {
  if (streams.isEmpty) return Stream.value(const []);
  if (streams.length == 1) return streams.single;
  final latest = List<List<T>?>.filled(streams.length, null);
  final subscriptions = <StreamSubscription<List<T>>>[];
  late final StreamController<List<T>> controller;
  controller = StreamController<List<T>>(
    onListen: () {
      for (var i = 0; i < streams.length; i++) {
        subscriptions.add(streams[i].listen((items) {
          latest[i] = items;
          if (latest.any((l) => l == null)) return;
          controller.add({for (final list in latest) for (final item in list!) idOf(item): item}.values.toList());
        }, onError: controller.addError));
      }
    },
    onCancel: () => Future.wait(subscriptions.map((s) => s.cancel())),
  );
  return controller.stream;
}
