import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../../core/l10n/app_localizations.dart';
import '../domain/voice_note_service.dart';

class VoiceRecordingResult {
  final String relativeFileName; // e.g. voice/voice_1730592819.m4a
  final String absolutePath;
  final int durationMs;
  final int sizeBytes;

  const VoiceRecordingResult({
    required this.relativeFileName,
    required this.absolutePath,
    required this.durationMs,
    required this.sizeBytes,
  });
}

class VoiceRecorderSheet extends StatefulWidget {
  const VoiceRecorderSheet({super.key});

  static Future<VoiceRecordingResult?> show(BuildContext context) {
    return showModalBottomSheet<VoiceRecordingResult?>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const VoiceRecorderSheet(),
    );
  }

  @override
  State<VoiceRecorderSheet> createState() => _VoiceRecorderSheetState();
}

class _VoiceRecorderSheetState extends State<VoiceRecorderSheet> {
  late final AudioRecorder _audioRecorder;
  Timer? _timer;
  Timer? _amplitudeTimer;

  bool _isRecording = false;
  bool _isPaused = false;
  int _durationMs = 0;
  double _amplitudeDb = -60.0;
  String? _currentFilePath;
  String? _currentRelativeName;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _initAndStartRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _amplitudeTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _initAndStartRecording() async {
    final status = await Permission.microphone.request();

    if (!mounted) return;

    if (status != PermissionStatus.granted) {
      final l10n = AppLocalizations.of(context);
      final isPermanentlyDenied = status == PermissionStatus.permanentlyDenied;

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.voicePermissionTitle),
          content: Text(l10n.voicePermissionDesc),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.cancel),
            ),
            if (isPermanentlyDenied)
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  openAppSettings();
                },
                child: Text(l10n.openSettings),
              )
            else
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _initAndStartRecording();
                },
                child: Text(l10n.grantPermission),
              ),
          ],
        ),
      );

      if (mounted) Navigator.of(context).pop(null);
      return;
    }

    // Prepare app-private storage folder: <documentsDir>/voice
    final appDir = await getApplicationDocumentsDirectory();
    final voiceDir = Directory(p.join(appDir.path, 'voice'));
    if (!await voiceDir.exists()) {
      await voiceDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'voice_$timestamp.m4a';
    final targetPath = p.join(voiceDir.path, fileName);
    _currentFilePath = targetPath;
    _currentRelativeName = 'voice/$fileName';

    // Start recording AAC-LC at 64kbps mono (Spec 14.2)
    const config = RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 64000,
      sampleRate: 44100,
      numChannels: 1,
    );

    await _audioRecorder.start(config, path: targetPath);

    setState(() {
      _isRecording = true;
      _isPaused = false;
      _durationMs = 0;
    });

    _startTimers();
  }

  void _startTimers() {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!_isPaused && mounted) {
        setState(() {
          _durationMs += 100;
        });

        // Safety cap at 60 minutes (Spec 14.3)
        if (_durationMs >= 3600000) {
          _stopAndSave();
        }
      }
    });

    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 150), (_) async {
      if (_isRecording && !_isPaused) {
        final amp = await _audioRecorder.getAmplitude();
        if (mounted) {
          setState(() {
            _amplitudeDb = amp.current;
          });
        }
      }
    });
  }

  Future<void> _togglePause() async {
    if (_isPaused) {
      await _audioRecorder.resume();
      setState(() => _isPaused = false);
    } else {
      await _audioRecorder.pause();
      setState(() => _isPaused = true);
    }
  }

  Future<void> _stopAndSave() async {
    _timer?.cancel();
    _amplitudeTimer?.cancel();

    final path = await _audioRecorder.stop();
    setState(() => _isRecording = false);

    if (path != null && _currentFilePath != null) {
      final file = File(path);
      int size = 0;
      if (await file.exists()) {
        size = await file.length();
      }

      final result = VoiceRecordingResult(
        relativeFileName: _currentRelativeName ?? 'voice/${p.basename(path)}',
        absolutePath: path,
        durationMs: _durationMs,
        sizeBytes: size,
      );

      if (mounted) Navigator.of(context).pop(result);
    } else {
      if (mounted) Navigator.of(context).pop(null);
    }
  }

  Future<void> _cancelRecording() async {
    final l10n = AppLocalizations.of(context);

    // If longer than 5 seconds, ask confirmation before discarding (Spec 14.3)
    if (VoiceNoteService.requiresDiscardConfirmation(_durationMs)) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.cancelRecording),
          content: Text(l10n.discardRecordingConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              child: Text(l10n.deleteTask),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    _timer?.cancel();
    _amplitudeTimer?.cancel();

    final path = await _audioRecorder.stop();
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }

    if (mounted) Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Normalized sound meter level between 0.0 and 1.0 (-60dB to 0dB)
    final normalizedAmp = ((_amplitudeDb + 60) / 60).clamp(0.05, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Text(
            l10n.addVoiceNote,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // Timer display
          Text(
            VoiceNoteService.formatDuration(_durationMs),
            style: theme.textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: _isPaused ? theme.colorScheme.outline : theme.colorScheme.primary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 16),

          // Simple Audio visualizer waves / meter
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(15, (index) {
                // Vary bar height based on amplitude and index
                final factor = (index % 3 == 0) ? 0.7 : (index % 2 == 0 ? 0.9 : 0.5);
                final barHeight = _isPaused
                    ? 4.0
                    : (36.0 * normalizedAmp * factor).clamp(4.0, 36.0);

                return Container(
                  width: 4,
                  height: barHeight,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  decoration: BoxDecoration(
                    color: _isPaused
                        ? theme.colorScheme.outlineVariant
                        : theme.colorScheme.primary.withOpacity(0.4 + (normalizedAmp * 0.6)),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 32),

          // Controls Row: Cancel, Pause/Resume, Stop & Save
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Cancel button
              IconButton.filledTonal(
                icon: const Icon(Icons.close_rounded, size: 26),
                tooltip: l10n.cancelRecording,
                style: IconButton.styleFrom(
                  minimumSize: const Size(54, 54),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
                onPressed: _cancelRecording,
              ),

              // Pause / Resume button
              IconButton.filledTonal(
                icon: Icon(
                  _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  size: 28,
                  color: theme.colorScheme.primary,
                ),
                tooltip: _isPaused ? l10n.resumeRecording : l10n.pauseRecording,
                style: IconButton.styleFrom(
                  minimumSize: const Size(60, 60),
                  backgroundColor: theme.colorScheme.primaryContainer.withOpacity(0.5),
                ),
                onPressed: _togglePause,
              ),

              // Stop & Save button (Large Primary Record Button)
              FilledButton.icon(
                icon: const Icon(Icons.check_rounded, size: 24),
                label: Text(l10n.stopRecording),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(120, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _stopAndSave,
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
