import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'health_todo_tab.dart';
import 'health_history_tab.dart';
import 'treatments_tab.dart';
import 'add_edit_health_item_sheet.dart';
import 'add_edit_treatment_sheet.dart';

class HealthScreen extends ConsumerStatefulWidget {
  const HealthScreen({super.key});

  @override
  ConsumerState<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends ConsumerState<HealthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddSelectionSheet() {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.withValues(alpha: 0.15),
                  child: const Icon(Icons.health_and_safety_rounded, color: Colors.blue),
                ),
                title: Text(isArabic ? 'إضافة فحص / تحليل / كشف طبيب' : 'Add Checkup / Test / Visit'),
                subtitle: Text(
                  isArabic ? 'جدولة ومتابعة الفحوصات والتحاليل الدورية' : 'Track pending checkups and tests',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const AddEditHealthItemSheet(),
                  );
                },
              ),
              const Divider(height: 8),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.purple.withValues(alpha: 0.15),
                  child: const Icon(Icons.medication_rounded, color: Colors.purple),
                ),
                title: Text(isArabic ? 'إضافة علاج / دواء جديد' : 'Add Medication / Treatment'),
                subtitle: Text(
                  isArabic ? 'متابعة الالتزام بالأدوية وتذكيرات الجرعات' : 'Track medication schedule & adherence',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const AddEditTreatmentSheet(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'الصحة والعلاج' : 'Health & Treatments'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.assignment_late_outlined, size: 20),
              text: isArabic ? 'المطلوب' : 'To do',
            ),
            Tab(
              icon: const Icon(Icons.history_rounded, size: 20),
              text: isArabic ? 'السجل' : 'History',
            ),
            Tab(
              icon: const Icon(Icons.medication_outlined, size: 20),
              text: isArabic ? 'العلاجات' : 'Treatments',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Mandatory Disclaimer Banner (Section 10.1 of CHANGES.md)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isArabic
                        ? 'التطبيق للمتابعة والتذكير فقط ولا يغني عن الطبيب.'
                        : 'For tracking and reminders only; it does not replace a doctor.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.blue.shade900,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tab Bar Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                HealthTodoTab(),
                HealthHistoryTab(),
                TreatmentsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSelectionSheet,
        tooltip: isArabic ? 'إضافة فحص أو علاج' : 'Add checkup or treatment',
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
