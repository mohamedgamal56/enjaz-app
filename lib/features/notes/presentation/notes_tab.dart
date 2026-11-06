import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import 'note_card.dart';
import 'add_note_sheet.dart';

class NotesTab extends ConsumerStatefulWidget {
  const NotesTab({super.key});

  @override
  ConsumerState<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends ConsumerState<NotesTab> {
  final _searchController = TextEditingController();
  String _selectedKind = 'all'; // all | note | quote | info

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final db = ref.watch(databaseProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      children: [
        // Search & Filters Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: isArabic ? 'بحث في الملاحظات والاقتباسات...' : 'Search notes...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: Text(isArabic ? 'الكل' : 'All'),
                      selected: _selectedKind == 'all',
                      onSelected: (_) => setState(() => _selectedKind = 'all'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      avatar: const Icon(Icons.note_outlined, size: 16),
                      label: Text(isArabic ? 'ملاحظات' : 'Notes'),
                      selected: _selectedKind == 'note',
                      onSelected: (_) => setState(() => _selectedKind = 'note'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      avatar: const Icon(Icons.format_quote_rounded, size: 16),
                      label: Text(isArabic ? 'اقتباسات وحِكم' : 'Quotes'),
                      selected: _selectedKind == 'quote',
                      onSelected: (_) => setState(() => _selectedKind = 'quote'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      avatar: const Icon(Icons.lightbulb_outline_rounded, size: 16),
                      label: Text(isArabic ? 'معلومات' : 'Info'),
                      selected: _selectedKind == 'info',
                      onSelected: (_) => setState(() => _selectedKind = 'info'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Notes List
        Expanded(
          child: StreamBuilder<List<Note>>(
            stream: db.watchNotes(
              searchQuery: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
              kind: _selectedKind,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final notes = snapshot.data ?? [];

              if (notes.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 64,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isArabic ? 'لا توجد ملاحظات مسجلة' : 'No notes yet',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isArabic
                            ? 'اكتب أفكارك اليومية، حِكمك المفضلة، أو معلومات تود تذكرها'
                            : 'Capture thoughts, quotes, wisdom, or reminders',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.add_rounded),
                        label: Text(isArabic ? 'إضافة ملاحظة جديدة' : 'Add Note'),
                        onPressed: () => AddNoteSheet.show(context),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: notes.length,
                itemBuilder: (context, index) {
                  return NoteCard(note: notes[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
