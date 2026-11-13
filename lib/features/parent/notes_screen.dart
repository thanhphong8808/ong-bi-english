// lib/features/parent/notes_screen.dart
//
// "Sổ tay của Bi" for parents: every fact Bi keeps about the child, with a
// delete button for each, "delete all", and a switch to stop Bi noting
// anything. Reached only through the parent gate.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../core/providers.dart';
import '../../curriculum/bi_notes.dart';
import '../../l10n/strings_vi.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  late final AppServices _services = ref.read(appServicesProvider);
  BiNotes? _notes;
  bool _on = true;
  int? _profileId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await ref.read(activeProfileProvider.future);
    final repo = _services.db.settingsRepo;
    final raw = await repo.read(BiNotes.key, profileId: profile.id);
    final off = await repo.read(BiNotes.offKey, profileId: profile.id);
    if (mounted) {
      setState(() {
        _profileId = profile.id;
        _notes = BiNotes.decode(raw);
        _on = off != '1';
      });
    }
  }

  Future<void> _save() async {
    final id = _profileId;
    final notes = _notes;
    if (id == null || notes == null) {
      return;
    }
    if (notes.isEmpty) {
      await _services.db.settingsRepo.delete(BiNotes.key, profileId: id);
    } else {
      await _services.db.settingsRepo.write(BiNotes.key, notes.encode(), profileId: id);
    }
  }

  Future<void> _setOn(bool on) async {
    final id = _profileId;
    if (id == null) {
      return;
    }
    setState(() => _on = on);
    if (on) {
      await _services.db.settingsRepo.delete(BiNotes.offKey, profileId: id);
    } else {
      await _services.db.settingsRepo.write(BiNotes.offKey, '1', profileId: id);
    }
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: const Text(S.notesClearAsk),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(S.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text(S.delete)),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _notes = BiNotes.decode(null));
      await _save();
    }
  }

  @override
  Widget build(BuildContext context) {
    final notes = _notes;
    return Scaffold(
      appBar: AppBar(title: const Text(S.notesTitle)),
      body: notes == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(S.notesIntro, style: TextStyle(fontSize: 15, color: AppColors.inkSoft)),
                const SizedBox(height: 12),
                Card(
                  child: SwitchListTile(
                    title: const Text(S.notesOn, style: TextStyle(fontWeight: FontWeight.w800)),
                    value: _on,
                    onChanged: _setOn,
                  ),
                ),
                const SizedBox(height: 8),
                if (notes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text(S.notesEmpty, style: TextStyle(fontSize: 16))),
                  )
                else
                  Card(
                    child: Column(
                      children: [
                        for (final n in notes.all)
                          ListTile(
                            title: Text(BiNotes.labelsVi[n.key] ?? n.key,
                                style: const TextStyle(fontSize: 14, color: AppColors.inkSoft)),
                            subtitle: Text(n.value,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
                            trailing: IconButton(
                              tooltip: S.delete,
                              icon: const Icon(Icons.delete_outline_rounded),
                              onPressed: () {
                                setState(() => notes.remove(n.key));
                                _save();
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                if (!notes.isEmpty) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _clear,
                    icon: const Icon(Icons.delete_sweep_rounded),
                    label: const Text(S.notesClear),
                  ),
                ],
              ],
            ),
    );
  }
}
