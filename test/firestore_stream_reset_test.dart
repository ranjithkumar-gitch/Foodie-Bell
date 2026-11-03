// A session reset must only rebuild Firestore streams that are already
// running — never open new whole-collection listeners (users, vendors,
// drivers…), which the rules refuse and which the session must not read.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiebell/data/providers/firestore_drivers_provider.dart';
import 'package:foodiebell/data/providers/firestore_managers_provider.dart';
import 'package:foodiebell/data/providers/firestore_stream_reset.dart';
import 'package:foodiebell/data/providers/firestore_users_provider.dart';
import 'package:foodiebell/data/providers/firestore_vendors_provider.dart';

void main() {
  test('resetting streams on sign-in creates no listener nobody asked for', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(firestoreStreamResetProvider)();
    for (final p in <ProviderBase<Object?>>[firestoreUsersProvider, firestoreVendorsProvider, firestoreDriversProvider, firestoreManagersProvider]) {
      expect(container.exists(p), isFalse, reason: '$p was created by the reset');
    }
  });

  test('a stream already in use is rebuilt', () {
    var builds = 0;
    final container = ProviderContainer(overrides: [
      firestoreUsersProvider.overrideWith((ref) {
        builds++;
        return const Stream.empty();
      }),
    ]);
    addTearDown(container.dispose);
    container.listen(firestoreUsersProvider, (_, _) {});
    expect(builds, 1);
    container.read(firestoreStreamResetProvider)();
    container.read(firestoreUsersProvider);
    expect(builds, 2);
  });
}
