import 'package:flutter/material.dart';

class DropPanel extends StatelessWidget {
  final VoidCallback onPickFile;
  final VoidCallback onPickFolder;

  const DropPanel({
    super.key,
    required this.onPickFile,
    required this.onPickFolder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 500;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 14 : 20),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            border: Border.all(color: Colors.blue.shade200, width: 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(
                Icons.upload_file,
                size: compact ? 36 : 48,
                color: Colors.blue.shade400,
              ),
              SizedBox(height: compact ? 8 : 12),
              Text(
                'Choose a file or folder to send',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: compact ? 14 : 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: compact ? 4 : 6),
              Text(
                'File and folder sending are available now.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: compact ? 12 : 13,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: compact ? 10 : 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: onPickFile,
                    icon: const Icon(Icons.insert_drive_file),
                    label: const Text('Choose File'),
                  ),
                  ElevatedButton.icon(
                    onPressed: onPickFolder,
                    icon: const Icon(Icons.folder),
                    label: const Text('Choose Folder'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
