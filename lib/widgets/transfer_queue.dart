import 'package:flutter/material.dart';
import '../models/transfer_task.dart';

class TransferQueue extends StatelessWidget {
  final List<TransferTask> tasks;

  const TransferQueue({
    super.key,
    required this.tasks,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transfer Queue',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: tasks.isEmpty
                ? const Center(
                    child: Text('No transfer task yet'),
                  )
                : ListView.separated(
                    itemCount: tasks.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: Colors.grey.shade300,
                    ),
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return ListTile(
                        title: Text(task.title),
                        subtitle: Text(
                          'To: ${task.targetDeviceNames.join(", ")}\nStatus: ${task.status}',
                        ),
                        trailing: SizedBox(
                          width: 80,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              LinearProgressIndicator(value: task.progress),
                              const SizedBox(height: 4),
                              Text('${(task.progress * 100).toInt()}%'),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}