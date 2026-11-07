import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../../core/db/app_database.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/money_formatter.dart';
import 'finance_icon_helper.dart';

class AddTransactionSheet extends ConsumerStatefulWidget {
  final Transaction? existingTransaction;
  final String? initialKind;
  final String? initialDate;

  const AddTransactionSheet({
    super.key,
    this.existingTransaction,
    this.initialKind,
    this.initialDate,
  });

  static Future<void> show(
    BuildContext context, {
    Transaction? existingTransaction,
    String? initialKind,
    String? initialDate,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionSheet(
        existingTransaction: existingTransaction,
        initialKind: initialKind,
        initialDate: initialDate,
      ),
    );
  }

  @override
  ConsumerState<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  late String _kind;
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  int? _selectedCategoryId;
  String _nature = 'side';
  String? _paymentMethod = 'cash';
  late DateTime _selectedDateTime;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingTransaction;
    _kind = existing?.kind ?? widget.initialKind ?? 'expense';
    _amountController = TextEditingController(
      text: existing != null ? MoneyFormatter.formatAmount(existing.amountMinor, showDecimals: false) : '',
    );
    _noteController = TextEditingController(text: existing?.note ?? '');
    _selectedCategoryId = existing?.categoryId;
    _nature = existing?.nature ?? 'side';
    _paymentMethod = existing?.paymentMethod ?? 'cash';

    if (existing != null) {
      _selectedDateTime = DateTime.fromMillisecondsSinceEpoch(existing.occurredAt);
    } else if (widget.initialDate != null) {
      final parts = widget.initialDate!.split('-');
      final now = DateTime.now();
      if (parts.length == 3) {
        _selectedDateTime = DateTime(
          int.tryParse(parts[0]) ?? now.year,
          int.tryParse(parts[1]) ?? now.month,
          int.tryParse(parts[2]) ?? now.day,
          now.hour,
          now.minute,
        );
      } else {
        _selectedDateTime = now;
      }
    } else {
      _selectedDateTime = DateTime.now();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _selectedDateTime.hour, minute: _selectedDateTime.minute),
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  void _save() async {
    final amountMinor = MoneyFormatter.parseToMinor(_amountController.text);
    if (amountMinor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('برجاء إدخال مبلغ صحيح')),
      );
      return;
    }
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('برجاء اختيار التصنيف')),
      );
      return;
    }

    final db = ref.read(databaseProvider);
    final now = DateTime.now().millisecondsSinceEpoch;
    final localDate =
        "${_selectedDateTime.year}-${_selectedDateTime.month.toString().padLeft(2, '0')}-${_selectedDateTime.day.toString().padLeft(2, '0')}";

    if (widget.existingTransaction != null) {
      await db.updateTransaction(
        TransactionsCompanion(
          id: drift.Value(widget.existingTransaction!.id),
          kind: drift.Value(_kind),
          amountMinor: drift.Value(amountMinor),
          categoryId: drift.Value(_selectedCategoryId!),
          nature: drift.Value(_nature),
          occurredAt: drift.Value(_selectedDateTime.millisecondsSinceEpoch),
          localDate: drift.Value(localDate),
          note: drift.Value(_noteController.text.trim().isEmpty ? null : _noteController.text.trim()),
          paymentMethod: drift.Value(_paymentMethod),
          updatedAt: drift.Value(now),
        ),
      );
    } else {
      await db.insertTransaction(
        TransactionsCompanion.insert(
          kind: _kind,
          amountMinor: amountMinor,
          categoryId: _selectedCategoryId!,
          nature: drift.Value(_nature),
          occurredAt: _selectedDateTime.millisecondsSinceEpoch,
          localDate: localDate,
          note: drift.Value(_noteController.text.trim().isEmpty ? null : _noteController.text.trim()),
          paymentMethod: drift.Value(_paymentMethod),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final numeralsFormat = ref.watch(numeralsProvider);
    final db = ref.watch(databaseProvider);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Kind Switcher: Expense / Income
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'expense',
                  icon: const Icon(Icons.arrow_downward_rounded, color: Colors.red),
                  label: Text(isArabic ? 'مصروف' : 'Expense'),
                ),
                ButtonSegment(
                  value: 'income',
                  icon: const Icon(Icons.arrow_upward_rounded, color: Colors.green),
                  label: Text(isArabic ? 'دخل' : 'Income'),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (set) {
                setState(() {
                  _kind = set.first;
                  _selectedCategoryId = null; // reset category for new kind
                });
              },
            ),
            const SizedBox(height: 16),

            // Big Amount Input Keypad
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: widget.existingTransaction == null,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: _kind == 'expense' ? Colors.red : Colors.green,
              ),
              decoration: InputDecoration(
                hintText: '0',
                suffixText: isArabic ? 'ج.م' : 'EGP',
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 12),

            // Categories Selector
            Text(
              isArabic ? 'التصنيف:' : 'Category:',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<FinanceCategory>>(
              stream: db.watchActiveFinanceCategories(kind: _kind),
              builder: (context, snapshot) {
                final categories = snapshot.data ?? [];
                if (categories.isEmpty) {
                  return const Text('لا توجد تصنيفات متاحة');
                }
                if (_selectedCategoryId == null && categories.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _selectedCategoryId == null) {
                      setState(() {
                        _selectedCategoryId = categories.first.id;
                        _nature = categories.first.nature;
                      });
                    }
                  });
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories.map((cat) {
                    final isSelected = _selectedCategoryId == cat.id;
                    final catColor = Color(cat.color);
                    return ChoiceChip(
                      selected: isSelected,
                      avatar: CircleAvatar(
                        radius: 10,
                        backgroundColor: isSelected ? Colors.white : catColor,
                        child: Icon(
                          FinanceIconHelper.getIcon(cat.icon),
                          size: 12,
                          color: isSelected ? catColor : Colors.white,
                        ),
                      ),
                      label: Text(isArabic ? cat.nameAr : (cat.nameEn ?? cat.nameAr)),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedCategoryId = cat.id;
                            if (cat.nature != 'none') {
                              _nature = cat.nature;
                            }
                          });
                        }
                      },
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 16),

            // Nature switch (only for expenses)
            if (_kind == 'expense') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isArabic ? 'طبيعة الإنفاق:' : 'Expense Nature:',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(value: 'essential', label: Text(isArabic ? 'ضروري' : 'Essential')),
                      ButtonSegment(value: 'side', label: Text(isArabic ? 'كمالي' : 'Side')),
                    ],
                    selected: {_nature},
                    onSelectionChanged: (set) {
                      setState(() => _nature = set.first);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Payment Method Chips
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isArabic ? 'طريقة الدفع:' : 'Payment Method:',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'cash',
                      icon: const Icon(Icons.money_rounded, size: 16),
                      label: Text(isArabic ? 'نقدي' : 'Cash'),
                    ),
                    ButtonSegment(
                      value: 'card',
                      icon: const Icon(Icons.credit_card_rounded, size: 16),
                      label: Text(isArabic ? 'كارت' : 'Card'),
                    ),
                    ButtonSegment(
                      value: 'wallet',
                      icon: const Icon(Icons.account_balance_wallet_rounded, size: 16),
                      label: Text(isArabic ? 'محفظة' : 'Wallet'),
                    ),
                  ],
                  selected: {_paymentMethod ?? 'cash'},
                  onSelectionChanged: (set) {
                    setState(() => _paymentMethod = set.first);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Date & Time Picker button
            InkWell(
              onTap: _pickDateTime,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, color: theme.colorScheme.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppFormatter.formatDate(
                          _selectedDateTime,
                          locale: Localizations.localeOf(context).languageCode,
                          format: numeralsFormat,
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      "${_selectedDateTime.hour.toString().padLeft(2, '0')}:${_selectedDateTime.minute.toString().padLeft(2, '0')}",
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Note Field
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.notes_rounded),
                labelText: isArabic ? 'ملاحظة (اختياري)' : 'Note (optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),

            // Save Button
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _save,
              icon: const Icon(Icons.check_rounded),
              label: Text(
                widget.existingTransaction == null
                    ? (isArabic ? 'حفظ المعاملة' : 'Save Transaction')
                    : (isArabic ? 'تحديث المعاملة' : 'Update Transaction'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
