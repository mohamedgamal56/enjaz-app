import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/db/app_database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/date_formatter.dart';
import '../../excel_export/presentation/excel_export_sheet.dart';
import '../../voice_notes/domain/voice_note_service.dart';
import '../domain/backup_models.dart';
import '../domain/backup_service.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _includeVoice = true;
  bool _isEncrypted = true;
  bool _obscureExportPassword = true;
  final TextEditingController _exportPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _exportPasswordController.dispose();
    super.dispose();
  }

  void _showLoading(String message) {
    setState(() => _isLoading = true);
  }

  void _hideLoading() {
    setState(() => _isLoading = false);
  }

  Future<void> _exportBackup() async {
    final l10n = AppLocalizations.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    String? password;
    if (_isEncrypted) {
      final pwd = _exportPasswordController.text.trim();
      if (pwd.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic
                  ? 'يرجى كتابة كلمة مرور لتشفير النسخة الاحتياطية'
                  : 'Please enter a password to encrypt the backup',
            ),
          ),
        );
        return;
      }
      password = pwd;
    }

    _showLoading(l10n.exportingBackup);

    try {
      final db = ref.read(databaseProvider);
      final file = await BackupService.exportFullBackup(
        db: db,
        includeVoice: _includeVoice,
        password: password,
      );

      _hideLoading();
      if (!mounted) return;

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Enjaz Backup',
      );
    } catch (e) {
      _hideLoading();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.errorExportingBackup}: $e')),
      );
    }
  }

  Future<void> _importBackup() async {
    final l10n = AppLocalizations.of(context);

    try {
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'enjaz'],
      );

      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      _showLoading(l10n.inspectingBackup);

      var preview = await BackupService.inspectBackupFile(file);
      String? enteredPassword;

      if (preview.isEncrypted) {
        _hideLoading();
        if (!mounted) return;

        enteredPassword = await _promptPasswordDialog(
          title: isArabic ? 'نسخة احتياطية مشفرة' : 'Encrypted Backup',
          message: isArabic
              ? 'هذا الملف مشفر بكلمة سر. أدخل كلمة السر لفك التشفير وقراءة البيانات:'
              : 'This file is password-encrypted. Enter password to decrypt:',
        );

        if (enteredPassword == null || enteredPassword.isEmpty) return;

        _showLoading(l10n.inspectingBackup);
        preview = await BackupService.inspectBackupFile(file, password: enteredPassword);
      }

      _hideLoading();
      if (!mounted) return;

      if (!preview.isValid) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.invalidBackupFile),
            content: Text(preview.errorMessage ?? l10n.invalidBackupFileDetails),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.ok),
              ),
            ],
          ),
        );
        return;
      }

      final confirmed = await _showRestorePreviewDialog(preview);
      if (confirmed != true) return;

      _showLoading(l10n.restoringBackup);
      final db = ref.read(databaseProvider);
      await BackupService.restoreBackup(
        db: db,
        zipFile: file,
        password: enteredPassword,
        createSafetySnapshot: true,
      );

      _hideLoading();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.restoreBackupSuccess),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _hideLoading();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.errorRestoringBackup}: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

    Future<String?> _promptPasswordDialog({
    required String title,
    required String message,
  }) {
    final controller = TextEditingController();
    var obscure = true;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.lock_rounded, color: Colors.amber),
              const SizedBox(width: 8),
              Expanded(child: Text(title)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                obscureText: obscure,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: isArabic ? 'كلمة المرور' : 'Password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.key_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setDlgState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: Text(isArabic ? 'إلغاء' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: Text(isArabic ? 'فك التشفير' : 'Decrypt'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showRestorePreviewDialog(BackupPreview preview) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final numeralsFormat = ref.read(numeralsProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final dateStr = preview.createdAt != null
        ? AppFormatter.formatDateTime(
            preview.createdAt!,
            locale: Localizations.localeOf(context).toString(),
            format: numeralsFormat,
          )
        : l10n.unknownDate;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Text(l10n.restoreConfirmTitle),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.restoreConfirmMessage,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _previewRow(l10n.backupDate, dateStr),
                  const Divider(height: 12),
                  _previewRow(l10n.tasksCountLabel, '${preview.tasksCount}'),
                  _previewRow(l10n.goalsCountLabel, '${preview.goalsCount}'),
                  _previewRow(l10n.ideasCountLabel, '${preview.ideasCount}'),
                  _previewRow(isArabic ? 'الملاحظات' : 'Notes', '${preview.notesCount}'),
                  _previewRow(isArabic ? 'العادات' : 'Habits', '${preview.habitsCount}'),
                  _previewRow(l10n.voiceNotesCountLabel, '${preview.voiceNotesCount}'),
                  _previewRow(
                    l10n.fileSizeLabel,
                    VoiceNoteService.formatFileSize(preview.fileSizeBytes),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.safetyCopyNotice,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: Text(l10n.restoreReplaceButton),
          ),
        ],
      ),
    );
  }

  Widget _previewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _exportTasksCsv() async {
    final l10n = AppLocalizations.of(context);
    _showLoading(l10n.exportingCsv);
    try {
      final db = ref.read(databaseProvider);
      final file = await BackupService.exportTasksCsv(db);
      _hideLoading();
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], subject: 'Tasks CSV');
    } catch (e) {
      _hideLoading();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.errorExportingCsv}: $e')),
      );
    }
  }

  Future<void> _exportEventsCsv() async {
    final l10n = AppLocalizations.of(context);
    _showLoading(l10n.exportingCsv);
    try {
      final db = ref.read(databaseProvider);
      final file = await BackupService.exportEventsCsv(db);
      _hideLoading();
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], subject: 'Events CSV');
    } catch (e) {
      _hideLoading();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.errorExportingCsv}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.backupAndSecurity),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Section 1: Full Backup (.zip)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.archive_outlined, color: theme.colorScheme.primary),
                          const SizedBox(width: 12),
                          Text(
                            l10n.fullBackupTitle,
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.fullBackupDescription,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.includeVoiceNotesToggle),
                        subtitle: Text(
                          _includeVoice
                              ? l10n.includeVoiceNotesSub
                              : l10n.withoutVoiceNotesSub,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        value: _includeVoice,
                        onChanged: (val) {
                          setState(() => _includeVoice = val);
                        },
                      ),
                      const Divider(height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Row(
                          children: [
                            Text(
                              isArabic
                                  ? 'مشفرة بكلمة سر (موصى بها)'
                                  : 'Password-encrypted (recommended)',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.security_rounded, size: 18, color: Colors.green),
                          ],
                        ),
                        subtitle: Text(
                          isArabic
                              ? 'تشفير AES-256 لحماية خصوصيتك وتسجيلاتك الصوتية'
                              : 'AES-256 encryption to protect your privacy and voice notes',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        value: _isEncrypted,
                        onChanged: (val) async {
                          if (!val) {
                            final proceed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
                                    const SizedBox(width: 8),
                                    Text(isArabic ? 'تنبيه أمان' : 'Security Warning'),
                                  ],
                                ),
                                content: Text(
                                  isArabic
                                      ? 'تصدير نسخة غير مشفرة يجعل بياناتك وملاحظاتك الشخصية قابلة للقراءة من أي شخص يملك الملف. هل أنت متأكد من المتابعة بدون كلمة سر؟'
                                      : 'Exporting an unencrypted backup leaves your personal data and notes readable by anyone with the file. Proceed without password?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(false),
                                    child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.of(ctx).pop(true),
                                    style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
                                    child: Text(isArabic ? 'تصدير بدون تشفير' : 'Export unencrypted'),
                                  ),
                                ],
                              ),
                            );
                            if (proceed == true) {
                              setState(() => _isEncrypted = false);
                            }
                          } else {
                            setState(() => _isEncrypted = true);
                          }
                        },
                      ),
                      if (_isEncrypted) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: _exportPasswordController,
                          obscureText: _obscureExportPassword,
                          decoration: InputDecoration(
                            labelText: isArabic ? 'كلمة مرور النسخة الاحتياطية' : 'Backup Password',
                            hintText: isArabic ? 'اكتب كلمة سر تتذكرها جيداً' : 'Enter a password you will remember',
                            prefixIcon: const Icon(Icons.password_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureExportPassword ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscureExportPassword = !_obscureExportPassword),
                            ),
                            border: const OutlineInputBorder(),
                            helperText: isArabic
                              ? 'تحذير: في حال نسيان كلمة المرور لن تتمكن من استرجاع البيانات'
                              : 'Warning: If forgotten, the backup cannot be recovered',
                            helperMaxLines: 2,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _exportBackup,
                          icon: const Icon(Icons.file_upload_outlined),
                          label: Text(l10n.exportBackupButton),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Section 2: Restore Backup (.zip)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.unarchive_outlined, color: theme.colorScheme.primary),
                          const SizedBox(width: 12),
                          Text(
                            l10n.restoreBackupTitle,
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.restoreBackupDescription,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _importBackup,
                          icon: const Icon(Icons.file_download_outlined),
                          label: Text(l10n.selectBackupFileButton),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Section 3: CSV Export
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.table_rows_outlined, color: theme.colorScheme.primary),
                          const SizedBox(width: 12),
                          Text(
                            l10n.csvExportTitle,
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.csvExportDescription,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          child: Icon(Icons.task_alt_rounded, size: 20),
                        ),
                        title: Text(l10n.tasksCsvTitle),
                        subtitle: Text(l10n.tasksCsvSubtitle),
                        trailing: IconButton(
                          icon: const Icon(Icons.share_outlined),
                          tooltip: l10n.exportTasksCsvTooltip,
                          onPressed: _exportTasksCsv,
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          child: Icon(Icons.history_rounded, size: 20),
                        ),
                        title: Text(l10n.eventsCsvTitle),
                        subtitle: Text(l10n.eventsCsvSubtitle),
                        trailing: IconButton(
                          icon: const Icon(Icons.share_outlined),
                          tooltip: l10n.exportEventsCsvTooltip,
                          onPressed: _exportEventsCsv,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Section 4: Excel Export Direct Card
              Card(
                child: ListTile(
                  leading: Icon(Icons.table_chart_rounded, color: theme.colorScheme.primary),
                  title: Text(l10n.exportExcel),
                  subtitle: Text(l10n.exportExcelSubtitle),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    ExcelExportSheet.show(context);
                  },
                ),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
