import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vision_ai/features/automation/data/repositories/device_automation_repository_impl.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';
import 'package:vision_ai/features/automation/domain/repositories/device_automation_repository.dart';

final contactSearchRepositoryProvider = Provider<ContactSearchRepository>((
  ref,
) {
  final repo = ref.watch(deviceAutomationRepositoryProvider);
  return ContactSearchRepository(repo);
});

/// Permission-guarded wrapper fetching real Android `ContactsContract` entries
/// for [ContactResolver]. Never invents synthetic contacts.
class ContactSearchRepository {
  const ContactSearchRepository(this._automationRepository);

  final DeviceAutomationRepository _automationRepository;

  Future<bool> hasContactsPermission() =>
      _automationRepository.checkPermission(AutomationPermission.readContacts);

  Future<bool> requestContactsPermission() => _automationRepository
      .requestPermission(AutomationPermission.readContacts);

  Future<List<ContactMatch>> loadAllSavedContacts() =>
      _automationRepository.getAllContacts();

  Future<List<ContactMatch>> queryDirectContacts(String query) =>
      _automationRepository.lookupContacts(query);
}
