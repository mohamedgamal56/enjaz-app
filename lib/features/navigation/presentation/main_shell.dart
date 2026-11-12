import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../security/domain/app_lock_provider.dart';
import '../../reminders/domain/notification_service.dart';
import '../../tasks/presentation/task_details_screen.dart';
import '../../backup/presentation/backup_screen.dart';
import '../../finance/presentation/finance_screen.dart';
import '../../health/presentation/health_screen.dart';
import '../../timeline/presentation/timeline_calendar_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/widgets/app_bottom_bar.dart';
import '../../../core/widgets/quick_add_menu.dart';
import '../../home/presentation/home_screen.dart';
import '../../finance/presentation/add_transaction_sheet.dart';
import '../../habits/presentation/add_habit_sheet.dart';
import '../../today/presentation/today_screen.dart';
import '../../plan/presentation/plan_screen.dart';
import '../../stats/presentation/stats_screen.dart';
import 'more_screen.dart';
import '../../tasks/presentation/quick_add_sheet.dart';
import '../../goals/presentation/add_goal_sheet.dart';
import '../../ideas/presentation/add_idea_sheet.dart';
import '../../notes/presentation/add_note_sheet.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../assistant/presentation/assistant_sheet.dart';
import '../../voice_notes/domain/unsaved_recording_recovery_service.dart';
import '../../../core/db/app_database.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  static const _channel = MethodChannel('com.enjaz.app/assistant');
  String? _pendingDestination;
  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'voiceShortcut') await _checkShortcut();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NotificationService().initialize(onSelectNotification: (payload) {
        _pendingDestination = payload;
        _openPending();
      });
      await _checkShortcut();
      // Batch 1: Unsaved recording recovery check (Spec 14.3)
      if (mounted) {
        final db = ref.read(databaseProvider);
        await UnsavedRecordingRecoveryService.checkAndPrompt(context, db);
      }
    });
  }
  Future<void> _checkShortcut() async {
    try {
      if (await _channel.invokeMethod<bool>('consumeShortcut') == true) {
        _pendingDestination = 'voice';
        _openPending();
      }
    } catch (_) {}
  }
  void _openPending() {
    if (!mounted || _pendingDestination == null) return;
    final destination = _pendingDestination!;

    final lock = ref.read(appLockProvider);
    if (lock.isLoading || lock.isLocked) return;
    _pendingDestination = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (destination == 'voice') { AssistantSheet.show(context); return; }
      final id = int.tryParse(destination.split(':').last);
      final Widget screen = destination.startsWith('task:') && id != null
        ? TaskDetailsScreen(taskId: id)
        : destination == 'backup' ? const BackupScreen()
        : destination.startsWith('obligation:') ? const FinanceScreen()
        : destination.startsWith('health_item:') || destination.startsWith('treatment:') ? const HealthScreen()
        : const TimelineCalendarScreen();
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    });
    WidgetsBinding.instance.scheduleFrame();
  }
  @override
  void dispose() { _channel.setMethodCallHandler(null); super.dispose(); }
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    PlanScreen(),
    StatsScreen(),
    MoreScreen(),
  ];

  Future<void> _onQuickAddPressed() async {
    final option = await QuickAddMenu.show(context);
    if (!mounted || option == null) return;

    switch (option) {
      case QuickAddOption.task:
        QuickAddSheet.show(context, initialKind: 'task');
        break;
      case QuickAddOption.errand:
        QuickAddSheet.show(context, initialKind: 'errand');
        break;
      case QuickAddOption.expense:
        AddTransactionSheet.show(context, initialKind: 'expense');
        break;
      case QuickAddOption.habit:
        AddHabitSheet.show(context);
        break;
      case QuickAddOption.note:
        AddNoteSheet.show(context);
        break;
      case QuickAddOption.idea:
        AddIdeaSheet.show(context);
        break;
      case QuickAddOption.voiceNote:
        AssistantSheet.show(context);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appLockProvider, (_, next) { if (!next.isLoading && !next.isLocked) _openPending(); });
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    // Top title changes per tab
    String getTitle() {
      switch (_currentIndex) {
        case 0:
          return l10n.appName;
        case 1:
          return isArabic ? 'التخطيط' : 'Plan';
        case 2:
          return l10n.tabStats;
        case 3:
          return isArabic ? 'المزيد' : 'More';
        default:
          return l10n.appName;
      }
    }

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
        }
      },
      child: Scaffold(
        appBar: (_currentIndex == 0 || _currentIndex == 2)
            ? null
            : AppBar(
                title: Text(
                  getTitle(),
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.mic_rounded),
                    tooltip: isArabic ? 'المساعد الذكي' : 'Assistant',
                    onPressed: () => AssistantSheet.show(context),
                  ),
                  if (_currentIndex != 3)
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      tooltip: l10n.settings,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        );
                      },
                    ),
                ],
              ),
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: AppBottomBar(
          currentIndex: _currentIndex,
          onTabSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          onAddPressed: _onQuickAddPressed,
        ),
      ),
    );
  }
}
