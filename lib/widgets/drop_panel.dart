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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border.all(color: Colors.blue.shade200, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.upload_file, size: 48, color: Colors.blue.shade400),
          const SizedBox(height: 12),
          const Text(
            'Choose a file to send now',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'File sending is real now. Folder sending will be added next.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
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
                label: const Text('Folder Later'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
