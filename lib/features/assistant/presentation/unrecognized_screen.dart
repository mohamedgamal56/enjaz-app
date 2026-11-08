import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/db/app_database.dart';

class UnrecognizedScreen extends ConsumerWidget {
  const UnrecognizedScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return Scaffold(appBar: AppBar(title: const Text('الجمل غير المفهومة'), actions: [
      IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'مسح السجل', onPressed: () async {
        final confirmed = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
          title: const Text('مسح الجمل المحفوظة؟'), actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('مسح'))]));
        if (confirmed == true) await db.delete(db.unrecognizedPhrases).go();
      })]), body: StreamBuilder<List<UnrecognizedPhrase>>(
        stream: db.select(db.unrecognizedPhrases).watch(), builder: (context, snapshot) {
          final items = snapshot.data ?? [];
          if (items.isEmpty) return const Center(child: Text('لا توجد جمل محفوظة'));
          return ListView(children: items.reversed.map((item) => ListTile(title: Text(item.phrase),
            subtitle: Text(DateTime.fromMillisecondsSinceEpoch(item.at).toLocal().toString()))).toList());
        }));
  }
}
