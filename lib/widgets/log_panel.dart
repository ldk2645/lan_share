import 'package:flutter/material.dart';

class LogPanel extends StatelessWidget {
  final List<String> logs;
  final VoidCallback onCopyAll;
  final VoidCallback onSaveLogs;

  const LogPanel({
    super.key,
    required this.logs,
    required this.onCopyAll,
    required this.onSaveLogs,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Logs', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: onCopyAll,
              icon: const Icon(Icons.copy_all),
              label: const Text('Copy All'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: onSaveLogs,
              icon: const Icon(Icons.save_alt),
              label: const Text('Save Logs'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1F2937)),
            ),
            child: logs.isEmpty
                ? const Center(
                    child: Text(
                      'No logs yet',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SelectableText(
                          log,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontFamily: 'monospace',
                            height: 1.4,
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
