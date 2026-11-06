import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/features/tasks/domain/task_selection_provider.dart';

void main() {
  group('TaskSelectionNotifier Tests (Round 1 Spec 1.8)', () {
    test('Enters selection mode on initial long press', () {
      final notifier = TaskSelectionNotifier();
      expect(notifier.state.isSelecting, isFalse);
      expect(notifier.state.selectedTaskIds.isEmpty, isTrue);

      notifier.enterSelection(10);
      expect(notifier.state.isSelecting, isTrue);
      expect(notifier.state.selectedTaskIds, {10});
    });

    test('Toggles selection of items correctly', () {
      final notifier = TaskSelectionNotifier();
      notifier.enterSelection(1);
      notifier.toggle(2);
      notifier.toggle(3);

      expect(notifier.state.selectedTaskIds, {1, 2, 3});

      // Deselect 2
      notifier.toggle(2);
      expect(notifier.state.selectedTaskIds, {1, 3});
    });

    test('Exits selection mode when last selected item is unselected', () {
      final notifier = TaskSelectionNotifier();
      notifier.enterSelection(5);
      expect(notifier.state.isSelecting, isTrue);

      notifier.toggle(5);
      expect(notifier.state.isSelecting, isFalse);
      expect(notifier.state.selectedTaskIds.isEmpty, isTrue);
    });

    test('Select All and Clear selection', () {
      final notifier = TaskSelectionNotifier();
      notifier.enterSelection(1);
      notifier.selectAll([1, 2, 3, 4, 5]);

      expect(notifier.state.selectedTaskIds.length, 5);
      expect(notifier.state.selectedTaskIds.contains(4), isTrue);

      notifier.clear();
      expect(notifier.state.isSelecting, isFalse);
      expect(notifier.state.selectedTaskIds.isEmpty, isTrue);
    });
  });
}
