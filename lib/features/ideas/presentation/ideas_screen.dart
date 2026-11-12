import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/widgets/widgets.dart';
import 'add_idea_sheet.dart';
import 'widgets/idea_card.dart';

class IdeasScreen extends ConsumerStatefulWidget {
  const IdeasScreen({super.key});

  @override
  ConsumerState<IdeasScreen> createState() => _IdeasScreenState();
}

class _IdeasScreenState extends ConsumerState<IdeasScreen> {
  final _searchController = TextEditingController();
  int _selectedStatusIndex = 0; // 0: new, 1: exploring, 2: converted, 3: archived
  int? _selectedTagId; // null = all tags

  String get _selectedStatusKey {
    switch (_selectedStatusIndex) {
      case 0:
        return 'new';
      case 1:
        return 'exploring';
      case 2:
        return 'converted';
      case 3:
        return 'archived';
      default:
        return 'new';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final db = ref.watch(databaseProvider);

    final statusFilters = [
      {'key': 'new', 'label': l10n.ideasNew},
      {'key': 'exploring', 'label': l10n.ideasExploring},
      {'key': 'converted', 'label': l10n.ideasConverted},
      {'key': 'archived', 'label': l10n.ideasArchived},
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search Bar & Mic Shortcut
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: SearchBar(
                      controller: _searchController,
                      hintText: l10n.searchIdeasHint,
                      leading: const Icon(Icons.search_rounded),
                      trailing: [
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                              });
                            },
                          ),
                      ],
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Mic Shortcut button (Spec 14.5: Quick voice idea recording)
                  IconButton.filledTonal(
                    icon: const Icon(Icons.mic_rounded),
                    tooltip: l10n.recordIdea,
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      minimumSize: const Size(52, 52),
                    ),
                    onPressed: () {
                      AddIdeaSheet.show(context, startWithRecorder: true);
                    },
                  ),
                ],
              ),
            ),

            // Status Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                children: List.generate(statusFilters.length, (index) {
                  final selected = _selectedStatusIndex == index;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      selected: selected,
                      label: Text(statusFilters[index]['label']!),
                      onSelected: (_) {
                        setState(() {
                          _selectedStatusIndex = index;
                        });
                      },
                    ),
                  );
                }),
              ),
            ),

            // Tags Filter Row
            StreamBuilder<List<Tag>>(
              stream: db.watchAllTags(),
              builder: (context, snapshot) {
                final allTags = snapshot.data ?? [];
                if (allTags.isEmpty) return const SizedBox.shrink();

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: Row(
                    children: [
                      // "All tags" chip
                      Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: ChoiceChip(
                          selected: _selectedTagId == null,
                          label: Text(l10n.allTags),
                          onSelected: (selected) {
                            if (selected) setState(() => _selectedTagId = null);
                          },
                        ),
                      ),
                      ...allTags.map((tag) {
                        final isSelected = _selectedTagId == tag.id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: ChoiceChip(
                            selected: isSelected,
                            label: Text('#${tag.name}'),
                            onSelected: (selected) {
                              setState(() {
                                _selectedTagId = selected ? tag.id : null;
                              });
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),

            // Ideas Grid / List
            Expanded(
              child: StreamBuilder<List<Idea>>(
                stream: db.watchIdeas(
                  status: _selectedStatusKey,
                  searchQuery: _searchController.text.trim(),
                  tagId: _selectedTagId,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final ideas = snapshot.data ?? [];

                  if (ideas.isEmpty) {
                    return Center(
                      child: EmptyState(
                        icon: Icons.lightbulb_outline_rounded,
                        title: l10n.emptyIdeasTitle,
                        subtitle: isArabic
                            ? 'لا توجد أفكار مسجلة في هذا القسم بعد'
                            : 'No ideas recorded in this section yet',
                        actionLabel: l10n.addIdea,
                        onAction: () => AddIdeaSheet.show(context),
                      ),
                    );
                  }

                  // Two-column Masonry / Grid layout (Spec 6.8)
                  return GridView.builder(
                    padding: const EdgeInsets.only(left: 12, right: 12, bottom: 84, top: 4),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: ideas.length,
                    itemBuilder: (context, index) {
                      return IdeaCard(idea: ideas[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
