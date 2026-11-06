import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../../core/db/app_database.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/money_formatter.dart';
import 'health_icon_helper.dart';

class AddEditHealthItemSheet extends ConsumerStatefulWidget {
  final HealthItem? itemToEdit;

  const AddEditHealthItemSheet({
    super.key,
    this.itemToEdit,
  });

  @override
  ConsumerState<AddEditHealthItemSheet> createState() => _AddEditHealthItemSheetState();
}

class _AddEditHealthItemSheetState extends ConsumerState<AddEditHealthItemSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _placeController;
  late TextEditingController _costController;

  late String _selectedKind;
  late DateTime _neededSince;
  DateTime? _dueBy;
  int? _repeatMonths;

  @override
  void initState() {
    super.initState();
    final item = widget.itemToEdit;
    _titleController = TextEditingController(text: item?.title ?? '');
    _placeController = TextEditingController(text: item?.placeOrDoctor ?? '');
    _costController = TextEditingController(
      text: item?.costMinor != null ? (item!.costMinor! / 100).toStringAsFixed(0) : '',
    );

    _selectedKind = item?.kind ?? 'checkup';
    if (item != null) {
      final parts = item.neededSince.split('-');
      if (parts.length == 3) {
        _neededSince = DateTime(
          int.tryParse(parts[0]) ?? DateTime.now().year,
          int.tryParse(parts[1]) ?? DateTime.now().month,
          int.tryParse(parts[2]) ?? DateTime.now().day,
        );
      } else {
        _neededSince = DateTime.now();
      }
      if (item.dueBy != null) {
        final dParts = item.dueBy!.split('-');
        if (dParts.length == 3) {
          _dueBy = DateTime(
            int.tryParse(dParts[0]) ?? DateTime.now().year,
            int.tryParse(dParts[1]) ?? DateTime.now().month,
            int.tryParse(dParts[2]) ?? DateTime.now().day,
          );
        }
      }
      _repeatMonths = item.repeatEveryMonths;
    } else {
      _neededSince = DateTime.now();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _placeController.dispose();
    _costController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isNeededSince}) async {
    final initial = isNeededSince ? _neededSince : (_dueBy ?? DateTime.now().add(const Duration(days: 7)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2046),
    );
    if (picked != null) {
      setState(() {
        if (isNeededSince) {
          _neededSince = picked;
        } else {
          _dueBy = picked;
        }
      });
    }
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final db = ref.read(databaseProvider);
    final title = _titleController.text.trim();
    final place = _placeController.text.trim();
    final costMinor = MoneyFormatter.parseToMinor(_costController.text.trim());
    final neededSinceStr = _formatDate(_neededSince);
    final dueByStr = _dueBy != null ? _formatDate(_dueBy!) : null;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (widget.itemToEdit != null) {
      final existing = widget.itemToEdit!;
      await db.updateHealthItem(
        HealthItemsCompanion(
          id: drift.Value(existing.id),
          title: drift.Value(title),
          kind: drift.Value(_selectedKind),
          neededSince: drift.Value(neededSinceStr),
          dueBy: drift.Value(dueByStr),
          placeOrDoctor: place.isNotEmpty ? drift.Value(place) : const drift.Value(null),
          repeatEveryMonths: drift.Value(_repeatMonths),
          costMinor: costMinor > 0 ? drift.Value(costMinor) : const drift.Value(null),
          updatedAt: drift.Value(now),
        ),
      );
    } else {
      await db.insertHealthItemWithEvent(
        HealthItemsCompanion.insert(
          title: title,
          kind: _selectedKind,
          status: const drift.Value('needed'),
          neededSince: neededSinceStr,
          dueBy: drift.Value(dueByStr),
          placeOrDoctor: place.isNotEmpty ? drift.Value(place) : const drift.Value(null),
          repeatEveryMonths: drift.Value(_repeatMonths),
          costMinor: costMinor > 0 ? drift.Value(costMinor) : const drift.Value(null),
          occurredAt: _neededSince.millisecondsSinceEpoch,
          localDate: neededSinceStr,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isEditing = widget.itemToEdit != null;

    final kinds = ['checkup', 'test', 'specialist', 'dental', 'vaccination', 'other'];

    return Padding(
      padding: EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 16.0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                    child: Icon(
                      HealthIconHelper.getKindIcon(_selectedKind),
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEditing
                        ? (isArabic ? 'تعديل الفحص / الكشف' : 'Edit Health Item')
                        : (isArabic ? 'إضافة فحص أو كشف جديد' : 'New Health Checkup / Test'),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Title input
              TextFormField(
                controller: _titleController,
                autofocus: !isEditing,
                decoration: InputDecoration(
                  labelText: isArabic ? 'اسم الفحص أو الكشف *' : 'Item Title *',
                  hintText: isArabic ? 'مثال: تحليل صورة دم، كشف عيون، تطعيم...' : 'e.g. Blood test, Eye checkup...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.title_rounded),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return isArabic ? 'برجاء كتابة اسم الفحص' : 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Kind Selector Chips
              Text(
                isArabic ? 'نوع الفحص:' : 'Kind:',
                style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kinds.map((kind) {
                  final isSelected = _selectedKind == kind;
                  return ChoiceChip(
                    avatar: Icon(
                      HealthIconHelper.getKindIcon(kind),
                      size: 16,
                      color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.primary,
                    ),
                    label: Text(HealthIconHelper.getKindLabel(kind, isArabic)),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedKind = kind);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Dates Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(isNeededSince: true),
                      icon: const Icon(Icons.calendar_today_rounded, size: 16),
                      label: Text(
                        '${isArabic ? 'مطلوب من:' : 'Needed since:'} ${_formatDate(_neededSince)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(isNeededSince: false),
                      icon: const Icon(Icons.event_available_rounded, size: 16),
                      label: Text(
                        _dueBy != null
                            ? '${isArabic ? 'الحد الأقصى:' : 'Due by:'} ${_formatDate(_dueBy!)}'
                            : (isArabic ? 'تحديد موعد أقصى' : 'Set due date'),
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Place or Doctor
              TextFormField(
                controller: _placeController,
                decoration: InputDecoration(
                  labelText: isArabic ? 'الطبيب أو المركز الطبي (اختياري)' : 'Doctor / Clinic (optional)',
                  hintText: isArabic ? 'مثال: د. أحمد فؤاد - عيادة الدقي' : 'e.g. Dr. Ahmed - City Clinic',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.local_hospital_rounded),
                ),
              ),
              const SizedBox(height: 16),

              // Cost & Repeat Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _costController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'التكلفة التقديرية (ج.م)' : 'Estimated cost (EGP)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.attach_money_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      value: _repeatMonths,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'التكرار الدوري' : 'Recurrence',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(isArabic ? 'بدون تكرار' : 'One time'),
                        ),
                        DropdownMenuItem<int?>(
                          value: 3,
                          child: Text(isArabic ? 'كل 3 شهور' : 'Every 3 mo'),
                        ),
                        DropdownMenuItem<int?>(
                          value: 6,
                          child: Text(isArabic ? 'كل 6 شهور' : 'Every 6 mo'),
                        ),
                        DropdownMenuItem<int?>(
                          value: 12,
                          child: Text(isArabic ? 'سنوياً (12 شهر)' : 'Yearly (12 mo)'),
                        ),
                      ],
                      onChanged: (val) => setState(() => _repeatMonths = val),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(
                    isEditing ? (isArabic ? 'حفظ التعديلات' : 'Save Changes') : (isArabic ? 'إضافة الفحص' : 'Add Item'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
