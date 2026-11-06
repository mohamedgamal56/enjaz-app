import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../../core/db/app_database.dart';
import '../domain/habits_service.dart';
import 'habit_icon_helper.dart';

class AddHabitSheet extends ConsumerStatefulWidget {
  final Habit? habitToEdit;
  final List<HabitItem>? existingItems;

  const AddHabitSheet({
    super.key,
    this.habitToEdit,
    this.existingItems,
  });

  static Future<void> show(
    BuildContext context, {
    Habit? habitToEdit,
    List<HabitItem>? existingItems,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddHabitSheet(
        habitToEdit: habitToEdit,
        existingItems: existingItems,
      ),
    );
  }

  @override
  ConsumerState<AddHabitSheet> createState() => _AddHabitSheetState();
}

class _AddHabitSheetState extends ConsumerState<AddHabitSheet> {
  late final TextEditingController _nameArController;
  late final TextEditingController _nameEnController;
  late final TextEditingController _unitController;
  late final TextEditingController _targetController;
  late final TextEditingController _checklistItemController;

  String _type = 'count'; // count | check | amount | checklist
  String _selectedColor = '#1976D2';
  String _selectedIcon = 'local_cafe_rounded';
  int _scheduleDays = 127; // all 7 days
  final List<String> _checklistItems = [];

  static const List<String> _colorOptions = [
    '#1976D2', // blue
    '#2E7D32', // green
    '#795548', // brown
    '#00796B', // teal
    '#0288D1', // light blue
    '#E64A19', // deep orange
    '#7B1FA2', // purple
    '#F57C00', // orange
    '#C2185B', // pink
    '#455A64', // blue grey
  ];

  static const List<String> _iconOptions = [
    'local_cafe_rounded',
    'mosque_rounded',
    'menu_book_rounded',
    'auto_awesome_rounded',
    'water_drop_rounded',
    'fitness_center_rounded',
    'directions_run_rounded',
    'bedtime_rounded',
    'alarm_rounded',
    'eco_rounded',
    'favorite_rounded',
    'star_rounded',
  ];

  @override
  void initState() {
    super.initState();
    final h = widget.habitToEdit;
    _nameArController = TextEditingController(text: h?.nameAr ?? '');
    _nameEnController = TextEditingController(text: h?.nameEn ?? '');
    _unitController = TextEditingController(text: h?.unit ?? '');
    _targetController = TextEditingController(
      text: h?.dailyTarget != null
          ? (h!.dailyTarget! % 1 == 0 ? h.dailyTarget!.toInt().toString() : h.dailyTarget.toString())
          : '',
    );
    _checklistItemController = TextEditingController();

    if (h != null) {
      _type = h.type;
      _selectedColor = h.color ?? '#1976D2';
      _selectedIcon = h.icon ?? 'local_cafe_rounded';
      _scheduleDays = h.scheduleDays;
    }

    if (widget.existingItems != null && widget.existingItems!.isNotEmpty) {
      _checklistItems.addAll(widget.existingItems!.map((i) => i.name));
    }
  }

  @override
  void dispose() {
    _nameArController.dispose();
    _nameEnController.dispose();
    _unitController.dispose();
    _targetController.dispose();
    _checklistItemController.dispose();
    super.dispose();
  }

  void _addChecklistItem() {
    final text = _checklistItemController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _checklistItems.add(text);
        _checklistItemController.clear();
      });
    }
  }

  void _removeChecklistItem(int index) {
    setState(() {
      _checklistItems.removeAt(index);
    });
  }

  Future<void> _saveHabit() async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final nameAr = _nameArController.text.trim();
    final nameEn = _nameEnController.text.trim();

    if (nameAr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isArabic ? 'يرجى إدخال اسم العادة' : 'Please enter habit name')),
      );
      return;
    }

    if (_type == 'checklist' && _checklistItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isArabic ? 'يرجى إضافة عنصر واحد على الأقل للقائمة' : 'Please add at least one item')),
      );
      return;
    }

    final db = ref.read(databaseProvider);
    final now = DateTime.now().millisecondsSinceEpoch;
    final todayStr = HabitsService.formatDate(DateTime.now());
    final targetVal = double.tryParse(_targetController.text.trim());
    final unitVal = _unitController.text.trim().isNotEmpty ? _unitController.text.trim() : null;

    if (widget.habitToEdit != null) {
      // Update
      await db.updateHabit(
        widget.habitToEdit!.toCompanion(true).copyWith(
              nameAr: drift.Value(nameAr),
              nameEn: drift.Value(nameEn.isNotEmpty ? nameEn : null),
              type: drift.Value(_type),
              unit: drift.Value(unitVal),
              dailyTarget: drift.Value(targetVal),
              icon: drift.Value(_selectedIcon),
              color: drift.Value(_selectedColor),
              scheduleDays: drift.Value(_scheduleDays),
              updatedAt: drift.Value(now),
            ),
      );

      // Replace checklist items if type is checklist
      if (_type == 'checklist') {
        final existing = await db.getHabitItems(widget.habitToEdit!.id);
        for (final item in existing) {
          await db.deleteHabitItem(item.id);
        }
        for (int i = 0; i < _checklistItems.length; i++) {
          await db.insertHabitItem(
            HabitItemsCompanion.insert(
              habitId: widget.habitToEdit!.id,
              name: _checklistItems[i],
              sortOrder: drift.Value(i),
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
      }
    } else {
      // Insert
      final habitId = await db.insertHabit(
        HabitsCompanion.insert(
          nameAr: nameAr,
          nameEn: drift.Value(nameEn.isNotEmpty ? nameEn : null),
          type: _type,
          unit: drift.Value(unitVal),
          dailyTarget: drift.Value(targetVal),
          icon: drift.Value(_selectedIcon),
          color: drift.Value(_selectedColor),
          scheduleDays: drift.Value(_scheduleDays),
          occurredAt: drift.Value(now),
          localDate: drift.Value(todayStr),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Insert checklist items
      if (_type == 'checklist') {
        for (int i = 0; i < _checklistItems.length; i++) {
          await db.insertHabitItem(
            HabitItemsCompanion.insert(
              habitId: habitId,
              name: _checklistItems[i],
              sortOrder: drift.Value(i),
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
      }
    }

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? (widget.habitToEdit != null ? 'تم تعديل العادة بنجاح' : 'تمت إضافة العادة بنجاح')
                : (widget.habitToEdit != null ? 'Habit updated successfully' : 'Habit added successfully'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isEdit = widget.habitToEdit != null;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(int.parse(_selectedColor.replaceFirst('#', '0xFF'))).withValues(alpha: 0.2),
                    child: Icon(
                      HabitIconHelper.getIcon(_selectedIcon),
                      color: Color(int.parse(_selectedColor.replaceFirst('#', '0xFF'))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEdit
                          ? (isArabic ? 'تعديل العادة' : 'Edit Habit')
                          : (isArabic ? 'إنشاء عادة جديدة' : 'New Habit'),
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  FilledButton(
                    onPressed: _saveHabit,
                    child: Text(isArabic ? 'حفظ' : 'Save'),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),

            // Form Body
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                children: [
                  // Habit Name
                  TextField(
                    controller: _nameArController,
                    decoration: InputDecoration(
                      labelText: isArabic ? 'اسم العادة *' : 'Habit Name *',
                      hintText: isArabic ? 'مثال: شرب الماء، قراءة، رياضة...' : 'e.g. Drink water, read...',
                      prefixIcon: const Icon(Icons.edit_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Habit Type Selector
                  Text(
                    isArabic ? 'نوع العادة' : 'Habit Type',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'count',
                        label: Text(isArabic ? 'عدّاد (+1)' : 'Count (+1)'),
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                      ),
                      ButtonSegment(
                        value: 'check',
                        label: Text(isArabic ? 'صح/لسه' : 'Check'),
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                      ),
                      ButtonSegment(
                        value: 'amount',
                        label: Text(isArabic ? 'كمية' : 'Amount'),
                        icon: const Icon(Icons.straighten_rounded, size: 16),
                      ),
                      ButtonSegment(
                        value: 'checklist',
                        label: Text(isArabic ? 'قائمة' : 'List'),
                        icon: const Icon(Icons.format_list_bulleted_rounded, size: 16),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (val) {
                      setState(() {
                        _type = val.first;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Target & Unit Fields (for count & amount)
                  if (_type == 'count' || _type == 'amount') ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _targetController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: isArabic ? 'الهدف اليومي (اختياري)' : 'Daily Target (Optional)',
                              hintText: isArabic ? 'مثال: 8' : 'e.g. 8',
                              prefixIcon: const Icon(Icons.flag_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _unitController,
                            decoration: InputDecoration(
                              labelText: isArabic ? 'الوحدة' : 'Unit',
                              hintText: isArabic ? 'كوب، صفحة، دقيقة...' : 'cups, pages, mins...',
                              prefixIcon: const Icon(Icons.category_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Checklist Items (for checklist type)
                  if (_type == 'checklist') ...[
                    Text(
                      isArabic ? 'عناصر القائمة اليومية' : 'Daily Checklist Items',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _checklistItemController,
                            onSubmitted: (_) => _addChecklistItem(),
                            decoration: InputDecoration(
                              labelText: isArabic ? 'إضافة عنصر للقائمة' : 'Add checklist item',
                              hintText: isArabic ? 'مثال: الفجر، الظهر...' : 'e.g. Item name...',
                              prefixIcon: const Icon(Icons.check_box_outline_blank_rounded),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          icon: const Icon(Icons.add_rounded),
                          onPressed: _addChecklistItem,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _checklistItems.length,
                      onReorder: (oldIdx, newIdx) {
                        setState(() {
                          if (newIdx > oldIdx) newIdx--;
                          final item = _checklistItems.removeAt(oldIdx);
                          _checklistItems.insert(newIdx, item);
                        });
                      },
                      itemBuilder: (context, index) {
                        return ListTile(
                          key: ValueKey('item_${_checklistItems[index]}_$index'),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          leading: const Icon(Icons.drag_handle_rounded),
                          title: Text(_checklistItems[index]),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                            onPressed: () => _removeChecklistItem(index),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Schedule Days (Bitmask)
                  Text(
                    isArabic ? 'أيام التكرار' : 'Repeat Days',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildSchedulePresetChip(
                        isArabic ? 'كل يوم' : 'Every Day',
                        127,
                      ),
                      _buildSchedulePresetChip(
                        isArabic ? 'أيام العمل' : 'Workdays',
                        31, // Mon-Fri = 1+2+4+8+16 = 31
                      ),
                      _buildSchedulePresetChip(
                        isArabic ? 'عطلة الأسبوع' : 'Weekends',
                        96, // Sat-Sun = 32+64 = 96
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Mon(1), Tue(2), Wed(4), Thu(8), Fri(16), Sat(32), Sun(64)
                      _buildDayToggle(isArabic ? 'سبت' : 'Sat', 32),
                      _buildDayToggle(isArabic ? 'أحد' : 'Sun', 64),
                      _buildDayToggle(isArabic ? 'إثنين' : 'Mon', 1),
                      _buildDayToggle(isArabic ? 'ثلاثاء' : 'Tue', 2),
                      _buildDayToggle(isArabic ? 'أربعاء' : 'Wed', 4),
                      _buildDayToggle(isArabic ? 'خميس' : 'Thu', 8),
                      _buildDayToggle(isArabic ? 'جمعة' : 'Fri', 16),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Color Picker
                  Text(
                    isArabic ? 'اللون المميز' : 'Color',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _colorOptions.map((colorHex) {
                        final isSelected = _selectedColor == colorHex;
                        final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
                        return GestureDetector(
                          onTap: () => setState(() => _selectedColor = colorHex),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.transparent,
                                width: 3,
                              ),
                              boxShadow: isSelected
                                  ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6, spreadRadius: 1)]
                                  : null,
                            ),
                            child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Icon Picker
                  Text(
                    isArabic ? 'الأيقونة' : 'Icon',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _iconOptions.map((iconKey) {
                      final isSelected = _selectedIcon == iconKey;
                      final iconData = HabitIconHelper.getIcon(iconKey);
                      final activeColor = Color(int.parse(_selectedColor.replaceFirst('#', '0xFF')));

                      return InkWell(
                        onTap: () => setState(() => _selectedIcon = iconKey),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected ? activeColor.withValues(alpha: 0.2) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? activeColor : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            iconData,
                            color: isSelected ? activeColor : theme.colorScheme.onSurfaceVariant,
                            size: 24,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchedulePresetChip(String label, int bitmask) {
    final isSelected = _scheduleDays == bitmask;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _scheduleDays = bitmask);
      },
    );
  }

  Widget _buildDayToggle(String label, int bit) {
    final isSelected = (_scheduleDays & bit) != 0;
    final activeColor = Color(int.parse(_selectedColor.replaceFirst('#', '0xFF')));

    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _scheduleDays &= ~bit;
          } else {
            _scheduleDays |= bit;
          }
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.shade400,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : null,
          ),
        ),
      ),
    );
  }
}
