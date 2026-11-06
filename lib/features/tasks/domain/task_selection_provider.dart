import 'package:flutter_riverpod/flutter_riverpod.dart';

class TaskSelectionState {
  final bool isSelecting;
  final Set<int> selectedTaskIds;

  const TaskSelectionState({
    this.isSelecting = false,
    this.selectedTaskIds = const {},
  });

  TaskSelectionState copyWith({
    bool? isSelecting,
    Set<int>? selectedTaskIds,
  }) {
    return TaskSelectionState(
      isSelecting: isSelecting ?? this.isSelecting,
      selectedTaskIds: selectedTaskIds ?? this.selectedTaskIds,
    );
  }
}

class TaskSelectionNotifier extends StateNotifier<TaskSelectionState> {
  TaskSelectionNotifier() : super(const TaskSelectionState());

  void enterSelection(int initialTaskId) {
    state = TaskSelectionState(isSelecting: true, selectedTaskIds: {initialTaskId});
  }

  void toggle(int taskId) {
    final newSet = Set<int>.from(state.selectedTaskIds);
    if (newSet.contains(taskId)) {
      newSet.remove(taskId);
      if (newSet.isEmpty) {
        state = const TaskSelectionState();
        return;
      }
    } else {
      newSet.add(taskId);
    }
    state = state.copyWith(selectedTaskIds: newSet);
  }

  void selectAll(Iterable<int> allIds) {
    state = state.copyWith(selectedTaskIds: allIds.toSet());
  }

  void clear() {
    state = const TaskSelectionState();
  }
}

final taskSelectionProvider =
    StateNotifierProvider<TaskSelectionNotifier, TaskSelectionState>((ref) {
  return TaskSelectionNotifier();
});
