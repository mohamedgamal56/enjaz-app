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
  bool _isLoading = false;

  void _showLoading(String message) {
    setState(() => _isLoading = true);
  }

  void _hideLoading() {
    setState(() => _isLoading = false);
  }

  Future<void> _exportBackup() async {
    final l10n = AppLocalizations.of(context);
    _showLoading(l10n.exportingBackup);

    try {
      final db = ref.read(databaseProvider);
      final file = await BackupService.exportFullBackup(
        db: db,
        includeVoice: _includeVoice,
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
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      _showLoading(l10n.inspectingBackup);

      final preview = await BackupService.inspectBackupFile(file);
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

  Future<bool?> _showRestorePreviewDialog(BackupPreview preview) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final numeralsFormat = ref.read(numeralsProvider);

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
