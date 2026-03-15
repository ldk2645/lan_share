import 'package:flutter/material.dart';

import '../models/device.dart';

class DeviceList extends StatelessWidget {
  final List<Device> devices;
  final ValueChanged<int> onToggle;
  final void Function(String deviceId)? onRemove;

  const DeviceList({
    super.key,
    required this.devices,
    required this.onToggle,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Online Devices', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: devices.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No device yet')),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: devices.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: Colors.grey.shade300),
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return CheckboxListTile(
                      value: device.selected,
                      onChanged: (_) => onToggle(index),
                      title: Row(
                        children: [
                          Expanded(child: Text(device.name)),
                          if (device.isManual)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Manual',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        '${device.ip}\ntext: ${device.textPort} file: ${device.filePort}',
                      ),
                      secondary: device.isManual
                          ? IconButton(
                              onPressed: onRemove == null
                                  ? null
                                  : () => onRemove!(device.id),
                              icon: const Icon(Icons.delete_outline),
                            )
                          : Icon(
                              Icons.circle,
                              size: 12,
                              color: device.online ? Colors.green : Colors.grey,
                            ),
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  },
                ),
        ),
      ],
    );
  }
}
