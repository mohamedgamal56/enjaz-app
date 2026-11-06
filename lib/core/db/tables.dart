import 'package:drift/drift.dart';

// Mixin for standard audit and soft-delete columns on every table
mixin CommonColumns on Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
}

// 1. Tasks
@TableIndex(name: 'idx_tasks_status', columns: {#status})
@TableIndex(name: 'idx_tasks_due_date', columns: {#dueDate})
@TableIndex(name: 'idx_tasks_deleted_at', columns: {#deletedAt})
@TableIndex(name: 'idx_tasks_goal_id', columns: {#goalId})
class Tasks extends Table with CommonColumns {
  TextColumn get title => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get kind => text().withDefault(const Constant('task'))(); // task | errand
  TextColumn get status => text().withDefault(const Constant('todo'))(); // todo | in_progress | partial | done | postponed | waiting | stopped
  TextColumn get priority => text().withDefault(const Constant('normal'))(); // low | normal | high
  TextColumn get dueDate => text().nullable()(); // YYYY-MM-DD
  TextColumn get dueTime => text().nullable()(); // HH:mm
  IntColumn get startedAt => integer().nullable()();
  IntColumn get finishedAt => integer().nullable()();
  IntColumn get progress => integer().withDefault(const Constant(0))(); // 0-100
  IntColumn get reasonId => integer().nullable().references(Reasons, #id)();
  TextColumn get reasonText => text().nullable()();
  TextColumn get outcomeNote => text().nullable()();
  TextColumn get postponedUntil => text().nullable()(); // YYYY-MM-DD
  IntColumn get postponeCount => integer().withDefault(const Constant(0))();
  TextColumn get locationText => text().nullable()();
  IntColumn get goalId => integer().nullable().references(Goals, #id)();
  IntColumn get milestoneId => integer().nullable().references(Milestones, #id)();
  IntColumn get reminderOffsetMinutes => integer().nullable()();
  IntColumn get recurrenceId => integer().nullable().references(Recurrences, #id)();
}

// 2. Task Events (Append-only history log)
@TableIndex(name: 'idx_task_events_at', columns: {#at})
@TableIndex(name: 'idx_task_events_task_id', columns: {#taskId})
class TaskEvents extends Table with CommonColumns {
  IntColumn get taskId => integer().references(Tasks, #id)();
  IntColumn get at => integer()(); // epoch ms
  TextColumn get fromStatus => text()();
  TextColumn get toStatus => text()();
  IntColumn get progress => integer()();
  IntColumn get reasonId => integer().nullable().references(Reasons, #id)();
  TextColumn get reasonText => text().nullable()();
  TextColumn get note => text().nullable()();
}

// 3. Reasons
class Reasons extends Table with CommonColumns {
  TextColumn get labelAr => text()();
  TextColumn get labelEn => text().nullable()();
  TextColumn get category => text()(); // postpone | waiting | stopped | partial | any
  BoolColumn get isDefault => boolean().withDefault(const Constant(true))();
  IntColumn get usageCount => integer().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

// 4. Goals
class Goals extends Table with CommonColumns {
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get progressMode => text().withDefault(const Constant('milestones'))(); // milestones | numeric
  RealColumn get targetValue => real().nullable()();
  RealColumn get currentValue => real().nullable()();
  TextColumn get unit => text().nullable()(); // e.g. جنيه
  TextColumn get startDate => text().nullable()();
  TextColumn get targetDate => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))(); // active | paused | done | abandoned
  IntColumn get completedAt => integer().nullable()();
  TextColumn get statusReason => text().nullable()();
}

// 5. Milestones
class Milestones extends Table with CommonColumns {
  IntColumn get goalId => integer().references(Goals, #id)();
  TextColumn get title => text()();
  TextColumn get notes => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get weight => integer().withDefault(const Constant(1))();
  TextColumn get dueDate => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending | done
  IntColumn get completedAt => integer().nullable()();
}

// 6. Goal Updates
class GoalUpdates extends Table with CommonColumns {
  IntColumn get goalId => integer().references(Goals, #id)();
  IntColumn get at => integer()();
  TextColumn get note => text().nullable()();
  RealColumn get valueDelta => real().nullable()();
}

// 7. Ideas
class Ideas extends Table with CommonColumns {
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('new'))(); // new | exploring | converted | archived
  TextColumn get convertedType => text().nullable()(); // task | goal
  IntColumn get convertedId => integer().nullable()();
}

// 8. Tags
class Tags extends Table with CommonColumns {
  TextColumn get name => text()();
}

// 9. Idea Tags
@DataClassName('IdeaTag')
class IdeaTags extends Table {
  IntColumn get ideaId => integer().references(Ideas, #id)();
  IntColumn get tagId => integer().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {ideaId, tagId};
}

// 10. Recurrences
class Recurrences extends Table with CommonColumns {
  TextColumn get rule => text()(); // daily | weekly | monthly
  IntColumn get weekdays => integer().withDefault(const Constant(0))();
  IntColumn get dayOfMonth => integer().nullable()();
  TextColumn get startsOn => text()();
  TextColumn get endsOn => text().nullable()();
  TextColumn get title => text()();
  TextColumn get kind => text()(); // task | errand
  TextColumn get dueTime => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get priority => text().withDefault(const Constant('normal'))();
  IntColumn get reminderOffsetMinutes => integer().nullable()();
  TextColumn get lastGeneratedUntil => text().nullable()();
}

// 11. Settings
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// 12. Voice Notes (Addendum v1.1)
@TableIndex(name: 'idx_voice_notes_parent', columns: {#parentType, #parentId})
class VoiceNotes extends Table with CommonColumns {
  TextColumn get parentType => text()(); // task | idea | goal
  IntColumn get parentId => integer()();
  TextColumn get fileName => text()(); // relative path inside voice/
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();
  TextColumn get label => text().nullable()();
  IntColumn get recordedAt => integer()(); // epoch ms
}

// 13. Reminders (Roadmap v2.0 Round 1 - Shared Reminders)
@TableIndex(name: 'idx_reminders_owner', columns: {#ownerType, #ownerId})
@TableIndex(name: 'idx_reminders_enabled', columns: {#enabled})
class Reminders extends Table with CommonColumns {
  TextColumn get ownerType => text()(); // task | goal | idea | habit | obligation | health_item | treatment
  IntColumn get ownerId => integer()();
  TextColumn get kind => text().withDefault(const Constant('notification'))(); // notification | alarm
  TextColumn get triggerType => text().withDefault(const Constant('offset'))(); // offset | absolute
  IntColumn get offsetMinutes => integer().nullable()(); // 0, 10, 30, 60, 1440
  DateTimeColumn get absoluteTime => dateTime().nullable()();
  TextColumn get message => text().nullable()(); // null = fallback to item title
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
}

// 14. Notes (Roadmap v2.0 Round 3 - Notes)
@TableIndex(name: 'idx_notes_date', columns: {#noteDate})
@TableIndex(name: 'idx_notes_pinned', columns: {#pinned})
@TableIndex(name: 'idx_notes_deleted', columns: {#deletedAt})
class Notes extends Table with CommonColumns {
  TextColumn get title => text().nullable()();
  TextColumn get body => text()();
  TextColumn get kind => text().withDefault(const Constant('note'))(); // note | quote | info
  TextColumn get color => text().nullable()();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  TextColumn get noteDate => text().nullable()(); // YYYY-MM-DD
  TextColumn get tags => text().nullable()();
  IntColumn get occurredAt => integer().nullable()();
  TextColumn get localDate => text().nullable()();
}


