import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/notification_service.dart';
import '../domain/notification_diagnostics.dart';

class ReminderCheckScreen extends StatefulWidget {
  const ReminderCheckScreen({super.key});
  @override
  State<ReminderCheckScreen> createState() => _ReminderCheckScreenState();
}

class _ReminderCheckScreenState extends State<ReminderCheckScreen>
    with WidgetsBindingObserver {
  bool _busy = true;
  bool? _notification, _exact, _battery;
  List<String> _channels = [], _pending = [], _log = [];
  AppLocalizations get strings =>
      lookupAppLocalizations(Localizations.localeOf(context));
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _busy = true);
    _notification = _exact = _battery = null;
    _channels = [];
    _pending = [];
    final service = NotificationService.instance;
    try {
      await service.initialize();
      _notification = await service.android?.areNotificationsEnabled();
      _exact = await service.areExactAlarmsPermitted();
      _battery = await Permission.ignoreBatteryOptimizations.isGranted;
      final channels = await service.android?.getNotificationChannels() ?? [];
      if (!mounted) return;
      _channels = channels
          .map((c) =>
              '${c.name}\n${c.id} • ${c.importance.value == 0 ? strings.diagnosticBlocked : strings.diagnosticEnabled} • ${strings.diagnosticSound}: ${c.playSound} • ${c.sound ?? "default"}')
          .toList();
      _pending =
          (await service.pendingRequests()).map((r) => '#${r.id}').toList();
    } catch (error) {
      await NotificationService.recordFailure(error);
    }
    _log = await NotificationDiagnostics.read();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _test(bool immediate) async {
    setState(() => _busy = true);
    final service = NotificationService.instance;
    bool accepted = false;
    try {
      if (immediate) {
        accepted = await service.testImmediateNotification(
            strings.diagnosticTitle, strings.diagnosticTestBody);
      } else {
        await service.testAlarmIn10Seconds(
            isArabic: Localizations.localeOf(context).languageCode == 'ar');
        accepted = service.activeScheduledPayloads
            .containsKey(NotificationService.idAlarmTest);
      }
    } catch (error) {
      await NotificationService.recordFailure(error);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(accepted
            ? strings.diagnosticSubmitted
            : strings.diagnosticFailed)));
    await _refresh();
  }

  Widget status(String label, bool? value) => ListTile(
        title: Text(label),
        trailing: Icon(
            value == true ? Icons.check_circle_outline : Icons.warning_amber,
            color: value == true
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.error),
      );
  @override
  Widget build(BuildContext context) {
    final s = strings;
    final labels = s.diagnosticPermissions.split(' / ');
    return Scaffold(
      appBar: AppBar(title: Text(s.diagnosticTitle), actions: [
        IconButton(
            onPressed: _busy ? null : _refresh,
            tooltip: s.diagnosticRefresh,
            icon: const Icon(Icons.refresh))
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (_busy) const LinearProgressIndicator(),
        status(labels[0], _notification),
        status(labels[1], _exact),
        status(labels[2], _battery),
        TextButton(
            onPressed: openAppSettings, child: Text(s.diagnosticSettings)),
        TextButton(
            onPressed: () async {
              try {
                await const MethodChannel('com.enjaz.app/assistant')
                    .invokeMethod('exactAlarmSettings');
              } catch (error) {
                await NotificationService.recordFailure(error);
              }
            },
            child: Text(s.diagnosticExactSettings)),
        if (_exact == false)
          Text(s.diagnosticDelayed,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        FilledButton(
            onPressed: _busy ? null : () => _test(true),
            child: Text(s.diagnosticImmediate)),
        FilledButton(
            onPressed: _busy ? null : () => _test(false),
            child: Text(s.diagnosticAlarm)),
        const SizedBox(height: 16),
        Text(s.diagnosticGuide),
        ListTile(title: Text(s.diagnosticChannels)),
        ..._channels.map((c) => Card(
            child: Padding(
                padding: const EdgeInsets.all(12), child: SelectableText(c)))),
        ListTile(
            title: Text(s.diagnosticPending),
            subtitle: Text(_pending.join(', '))),
        ListTile(title: Text(s.diagnosticLog)),
        ..._log.map((line) {
          final data = jsonDecode(line) as Map<String, dynamic>;
          final message = switch (data['code']) {
            'notifications_disabled' => s.diagnosticDisabled,
            'channel_disabled' => s.diagnosticChannelDisabled,
            'inexact_fallback' => s.diagnosticDelayed,
            'scheduled' || 'show_requested' => s.diagnosticScheduled,
            'schedule_not_found' => s.diagnosticMissing,
            _ => s.diagnosticFailed,
          };
          return ListTile(
              title: Text(message),
              subtitle: SelectableText(
                  '${data['code']} • ${data['at']} • #${data['id'] ?? "—"}'));
        }),
      ]),
    );
  }
}
