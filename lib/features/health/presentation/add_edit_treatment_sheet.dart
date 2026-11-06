import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../../core/db/app_database.dart';
import '../../../core/utils/money_formatter.dart';
import 'health_icon_helper.dart';

class AddEditTreatmentSheet extends ConsumerStatefulWidget {
  final Treatment? treatmentToEdit;

  const AddEditTreatmentSheet({
    super.key,
    this.treatmentToEdit,
  });

  @override
  ConsumerState<AddEditTreatmentSheet> createState() => _AddEditTreatmentSheetState();
}

class _AddEditTreatmentSheetState extends ConsumerState<AddEditTreatmentSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _instructionsController;
  late TextEditingController _costController;
  late TextEditingController _stoppedReasonController;

  late DateTime _startDate;
  DateTime? _endDate;
  bool _purchased = false;
  String _adherence = 'following';

  @override
  void initState() {
    super.initState();
    final tr = widget.treatmentToEdit;
    _nameController = TextEditingController(text: tr?.name ?? '');
    _instructionsController = TextEditingController(text: tr?.instructionsNote ?? '');
    _costController = TextEditingController(
      text: tr?.purchaseCostMinor != null ? (tr!.purchaseCostMinor! / 100).toStringAsFixed(0) : '',
    );
    _stoppedReasonController = TextEditingController(text: tr?.stoppedReason ?? '');

    if (tr != null) {
      _purchased = tr.purchased;
      _adherence = tr.adherence;
      final sParts = tr.startDate.split('-');
      if (sParts.length == 3) {
        _startDate = DateTime(
          int.tryParse(sParts[0]) ?? DateTime.now().year,
          int.tryParse(sParts[1]) ?? DateTime.now().month,
          int.tryParse(sParts[2]) ?? DateTime.now().day,
        );
      } else {
        _startDate = DateTime.now();
      }
      if (tr.endDate != null) {
        final eParts = tr.endDate!.split('-');
        if (eParts.length == 3) {
          _endDate = DateTime(
            int.tryParse(eParts[0]) ?? DateTime.now().year,
            int.tryParse(eParts[1]) ?? DateTime.now().month,
            int.tryParse(eParts[2]) ?? DateTime.now().day,
          );
        }
      }
    } else {
      _startDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _instructionsController.dispose();
    _costController.dispose();
    _stoppedReasonController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : (_endDate ?? _startDate.add(const Duration(days: 7)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2046),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final db = ref.read(databaseProvider);
    final name = _nameController.text.trim();
    final instructions = _instructionsController.text.trim();
    final costMinor = MoneyFormatter.parseToMinor(_costController.text.trim());
    final stoppedReason = _stoppedReasonController.text.trim();
    final startDateStr = _formatDate(_startDate);
    final endDateStr = _endDate != null ? _formatDate(_endDate!) : null;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (widget.treatmentToEdit != null) {
      final existing = widget.treatmentToEdit!;
      await db.updateTreatment(
        TreatmentsCompanion(
          id: drift.Value(existing.id),
          name: drift.Value(name),
          instructionsNote: instructions.isNotEmpty ? drift.Value(instructions) : const drift.Value(null),
          startDate: drift.Value(startDateStr),
          endDate: drift.Value(endDateStr),
          purchased: drift.Value(_purchased),
          purchaseCostMinor: costMinor > 0 ? drift.Value(costMinor) : const drift.Value(null),
          adherence: drift.Value(_adherence),
          stoppedReason: _adherence == 'stopped' && stoppedReason.isNotEmpty ? drift.Value(stoppedReason) : const drift.Value(null),
          updatedAt: drift.Value(now),
        ),
      );
    } else {
      await db.insertTreatment(
        TreatmentsCompanion.insert(
          name: name,
          instructionsNote: instructions.isNotEmpty ? drift.Value(instructions) : const drift.Value(null),
          startDate: startDateStr,
          endDate: drift.Value(endDateStr),
          purchased: drift.Value(_purchased),
          purchasedAt: _purchased ? drift.Value(now) : const drift.Value.absent(),
          purchaseCostMinor: costMinor > 0 ? drift.Value(costMinor) : const drift.Value.absent(),
          adherence: drift.Value(_adherence),
          stoppedReason: _adherence == 'stopped' && stoppedReason.isNotEmpty ? drift.Value(stoppedReason) : const drift.Value.absent(),
          occurredAt: _startDate.millisecondsSinceEpoch,
          localDate: startDateStr,
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
    final isEditing = widget.treatmentToEdit != null;

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
                    backgroundColor: Colors.purple.withValues(alpha: 0.15),
                    child: const Icon(Icons.medication_rounded, color: Colors.purple),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEditing
                        ? (isArabic ? 'تعديل بيانات العلاج' : 'Edit Treatment')
                        : (isArabic ? 'إضافة علاج / دواء جديد' : 'New Medication / Treatment'),
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

              // Treatment Name
              TextFormField(
                controller: _nameController,
                autofocus: !isEditing,
                decoration: InputDecoration(
                  labelText: isArabic ? 'اسم الدواء أو الكورس العلاجي *' : 'Medication / Treatment Name *',
                  hintText: isArabic ? 'مثال: أوجمنتين 1 جم، جلسات علاج طبيعي...' : 'e.g. Augmentin 1g, Physio sessions...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.medication_outlined),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return isArabic ? 'برجاء كتابة اسم الدواء' : 'Please enter treatment name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Instructions
              TextFormField(
                controller: _instructionsController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: isArabic ? 'تعليمات الجرعة والاستخدام (اختياري)' : 'Instructions & Dosage (optional)',
                  hintText: isArabic ? 'مثال: قرص كل 12 ساعة بعد الأكل لمدة 7 أيام' : 'e.g. 1 tablet every 12h after food for 7 days',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 16),

              // Dates Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(isStart: true),
                      icon: const Icon(Icons.play_circle_outline_rounded, size: 16),
                      label: Text(
                        '${isArabic ? 'البدء:' : 'Start:'} ${_formatDate(_startDate)}',
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
                      onPressed: () => _pickDate(isStart: false),
                      icon: const Icon(Icons.stop_circle_outlined, size: 16),
                      label: Text(
                        _endDate != null
                            ? '${isArabic ? 'الانتهاء:' : 'End:'} ${_formatDate(_endDate!)}'
                            : (isArabic ? 'تاريخ الانتهاء' : 'End date'),
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

              // Purchased switch & cost
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(isArabic ? 'تم شراء الدواء' : 'Medication Purchased'),
                subtitle: Text(
                  isArabic ? 'حدد إذا قمت بشراء الدواء بالفعل' : 'Check if you have already bought the medication',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                ),
                value: _purchased,
                onChanged: (val) => setState(() => _purchased = val),
              ),
              if (_purchased) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _costController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'سعر الشراء (ج.م)' : 'Purchase Cost (EGP)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.attach_money_rounded),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Adherence status
              DropdownButtonFormField<String>(
                value: _adherence,
                decoration: InputDecoration(
                  labelText: isArabic ? 'حالة المتابعة والالتزام' : 'Adherence Status',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(
                    Icons.circle,
                    size: 16,
                    color: HealthIconHelper.getAdherenceColor(_adherence),
                  ),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'following',
                    child: Text(isArabic ? 'ملتزم بالعلاج' : 'Following'),
                  ),
                  DropdownMenuItem(
                    value: 'not_started',
                    child: Text(isArabic ? 'لم أبدأ بعد' : 'Not started'),
                  ),
                  DropdownMenuItem(
                    value: 'stopped',
                    child: Text(isArabic ? 'متوقف عن العلاج' : 'Stopped'),
                  ),
                  DropdownMenuItem(
                    value: 'completed',
                    child: Text(isArabic ? 'اكتمل العلاج' : 'Completed'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _adherence = val);
                },
              ),
              if (_adherence == 'stopped') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _stoppedReasonController,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'سبب إيقاف العلاج *' : 'Reason for stopping *',
                    hintText: isArabic ? 'مثال: بأمر الطبيب، ظهور أعراض جانبية...' : 'e.g. Doctor advice, side effects...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.warning_amber_rounded),
                  ),
                  validator: (val) {
                    if (_adherence == 'stopped' && (val == null || val.trim().isEmpty)) {
                      return isArabic ? 'برجاء ذكر سبب التوقف' : 'Please provide reason';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(
                    isEditing ? (isArabic ? 'حفظ التعديلات' : 'Save Changes') : (isArabic ? 'إضافة العلاج' : 'Add Treatment'),
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
