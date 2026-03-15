import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/device.dart';
import '../models/transfer_task.dart';
import '../services/connectivity_test_service.dart';
import '../services/discovery_service.dart';
import '../services/file_transfer_service.dart';
import '../services/log_service.dart';
import '../services/message_service.dart';
import '../services/save_location_service.dart';
import '../utils/network_utils.dart';
import '../widgets/connectivity_test_box.dart';
import '../widgets/device_list.dart';
import '../widgets/drop_panel.dart';
import '../widgets/log_panel.dart';
import '../widgets/manual_device_box.dart';
import '../widgets/text_send_box.dart';
import '../widgets/transfer_queue.dart';

class DesktopHomePage extends StatefulWidget {
  const DesktopHomePage({super.key});

  @override
  State<DesktopHomePage> createState() => _DesktopHomePageState();
}

class _DesktopHomePageState extends State<DesktopHomePage> {
  final TextEditingController _textController = TextEditingController();

  late final DiscoveryService _discoveryService;
  late final MessageService _messageService;
  late final FileTransferService _fileTransferService;

  StreamSubscription<List<Device>>? _deviceSub;
  StreamSubscription<List<String>>? _logSub;
  StreamSubscription<ReceivedTextMessage>? _messageSub;
  StreamSubscription<ReceivedFileRecord>? _fileSub;
  StreamSubscription<ReceivedFolderRecord>? _folderSub;

  List<Device> _devices = <Device>[];
  List<TransferTask> _tasks = <TransferTask>[];
  List<String> _logs = <String>[];
  List<ReceivedTextMessage> _receivedMessages = <ReceivedTextMessage>[];
  List<ReceivedFileRecord> _receivedFiles = <ReceivedFileRecord>[];
  List<ReceivedFolderRecord> _receivedFolders = <ReceivedFolderRecord>[];

  String _localIp = 'Loading...';

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    await LogService.instance.init();

    final ip = await NetworkUtils.findLocalIpv4();
    if (mounted) {
      setState(() {
        _localIp = ip;
      });
    }

    _discoveryService = DiscoveryService(
      selfId: _buildSelfId(),
      selfName: _buildDesktopName(),
    );

    _messageService = MessageService(selfName: _buildDesktopName());

    _fileTransferService = FileTransferService(selfName: _buildDesktopName());

    _deviceSub = _discoveryService.devicesStream.listen((devices) {
      if (!mounted) return;
      setState(() {
        _devices = devices;
      });
    });

    _logSub = LogService.instance.logsStream.listen((logs) {
      if (!mounted) return;
      setState(() {
        _logs = logs;
      });
    });

    _messageSub = _messageService.messageStream.listen((message) {
      _discoveryService.rememberPeer(
        name: message.fromDeviceName,
        ip: message.fromIp,
        textPort: message.fromTextPort,
        filePort: message.fromFilePort,
      );

      if (!mounted) return;
      setState(() {
        _receivedMessages = <ReceivedTextMessage>[
          message,
          ..._receivedMessages,
        ];
      });
    });

    _fileSub = _fileTransferService.receivedFileStream.listen((file) {
      _discoveryService.rememberPeer(
        name: file.fromDeviceName,
        ip: file.fromIp,
        textPort: file.fromTextPort,
        filePort: file.fromFilePort,
      );

      if (!mounted) return;
      setState(() {
        _receivedFiles = <ReceivedFileRecord>[file, ..._receivedFiles];
      });
    });

    _folderSub = _fileTransferService.receivedFolderStream.listen((folder) {
      _discoveryService.rememberPeer(
        name: folder.fromDeviceName,
        ip: folder.fromIp,
        textPort: folder.fromTextPort,
        filePort: folder.fromFilePort,
      );

      if (!mounted) return;
      setState(() {
        _receivedFolders = <ReceivedFolderRecord>[folder, ..._receivedFolders];
      });
    });

    if (mounted) {
      setState(() {
        _logs = LogService.instance.currentLogs;
      });
    }

    await _messageService.start();
    await _fileTransferService.startReceiver();
    await _discoveryService.start();
  }

  String _buildSelfId() {
    return 'desktop-${Platform.localHostname}-${DateTime.now().millisecondsSinceEpoch}';
  }

  String _buildDesktopName() {
    final name = Platform.localHostname.trim();
    if (name.isEmpty) {
      return 'Windows Device';
    }
    return name;
  }

  @override
  void dispose() {
    _textController.dispose();
    _deviceSub?.cancel();
    _logSub?.cancel();
    _messageSub?.cancel();
    _fileSub?.cancel();
    _folderSub?.cancel();
    _discoveryService.dispose();
    _messageService.dispose();
    _fileTransferService.dispose();
    super.dispose();
  }

  void _toggleDevice(int index) {
    final device = _devices[index];
    _discoveryService.updateDeviceSelection(device.id, !device.selected);
  }

  void _addManualDevice(String name, String ip, int textPort, int filePort) {
    _discoveryService.addManualDevice(
      name: name,
      ip: ip,
      textPort: textPort,
      filePort: filePort,
    );
    _showMessage('Manual device added');
  }

  void _removeDevice(String deviceId) {
    _discoveryService.removeDevice(deviceId);
    _showMessage('Device removed');
  }

  List<Device> _selectedDevices() {
    return _devices.where((device) => device.selected).toList();
  }

  Device? _findDeviceByIp(String host) {
    for (final device in _devices) {
      if (device.ip == host) {
        return device;
      }
    }
    return null;
  }

  Future<void> _sendText() async {
    final text = _textController.text;
    final selectedDevices = _selectedDevices();

    if (text.trim().isEmpty || selectedDevices.isEmpty) {
      _showMessage('Please input text and select at least one device');
      await LogService.instance.warn(
        'Send text blocked: empty text or no selected device',
      );
      return;
    }

    await _messageService.sendTextToDevices(
      text: text,
      fromName: _buildDesktopName(),
      fromIp: _localIp,
      devices: selectedDevices,
      contentType: 'text/plain',
      preserveFormat: true,
    );

    setState(() {
      _tasks = <TransferTask>[
        TransferTask(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: 'Text (${text.length} chars)',
          targetDeviceNames: selectedDevices.map((e) => e.name).toList(),
          progress: 1,
          status: 'Sent',
        ),
        ..._tasks,
      ];
    });

    _textController.clear();
    _showMessage('Text sent');
  }

  Future<void> _pickAndSendFile() async {
    final selectedDevices = _selectedDevices();

    if (selectedDevices.isEmpty) {
      _showMessage('Please select at least one device');
      await LogService.instance.warn('Send file blocked: no device selected');
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: false,
      withReadStream: false,
      lockParentWindow: true,
    );

    if (result == null || result.files.isEmpty) {
      await LogService.instance.warn('File pick canceled by user');
      return;
    }

    final path = result.files.first.path;
    if (path == null || path.trim().isEmpty) {
      _showMessage('Cannot read picked file path');
      await LogService.instance.error('Picked file path is empty');
      return;
    }

    final file = File(path);
    final fileName = file.uri.pathSegments.last;
    final fileSize = await file.length();

    final task = TransferTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: fileName,
      targetDeviceNames: selectedDevices.map((e) => e.name).toList(),
      progress: 0.1,
      status: 'Sending file...',
    );

    setState(() {
      _tasks = <TransferTask>[task, ..._tasks];
    });

    await _fileTransferService.sendFileToDevices(
      file: file,
      fromName: _buildDesktopName(),
      fromIp: _localIp,
      devices: selectedDevices,
    );

    setState(() {
      task.progress = 1;
      task.status = 'File sent (${fileSize} bytes)';
    });

    _showMessage('File sent');
  }

  Future<void> _pickAndSendFolder() async {
    final selectedDevices = _selectedDevices();

    if (selectedDevices.isEmpty) {
      _showMessage('Please select at least one device');
      await LogService.instance.warn('Send folder blocked: no device selected');
      return;
    }

    final folderPath = await FilePicker.platform.getDirectoryPath(
      lockParentWindow: true,
    );

    if (folderPath == null || folderPath.trim().isEmpty) {
      await LogService.instance.warn('Folder pick canceled by user');
      return;
    }

    final folder = Directory(folderPath);
    final folderName = folder.uri.pathSegments.where((e) => e.isNotEmpty).last;

    final task = TransferTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '$folderName/',
      targetDeviceNames: selectedDevices.map((e) => e.name).toList(),
      progress: 0.1,
      status: 'Sending folder...',
    );

    setState(() {
      _tasks = <TransferTask>[task, ..._tasks];
    });

    await _fileTransferService.sendFolderToDevices(
      folder: folder,
      fromName: _buildDesktopName(),
      fromIp: _localIp,
      devices: selectedDevices,
    );

    setState(() {
      task.progress = 1;
      task.status = 'Folder sent';
    });

    _showMessage('Folder sent');
  }

  Future<void> _copyAllLogs() async {
    final text = LogService.instance.allLogsText;
    await Clipboard.setData(ClipboardData(text: text));
    _showMessage('Logs copied');
  }

  Future<void> _saveLogs() async {
    final path = await LogService.instance.exportLogs();
    await LogService.instance.info('Logs exported to $path');
    _showMessage('Logs saved: $path');
  }

  Future<void> _testConnection(String host) async {
    await LogService.instance.info('Start connection test to $host');

    final matched = _findDeviceByIp(host);
    final textPort = matched?.textPort ?? 40402;
    final filePort = matched?.filePort ?? 40403;

    final textResult = await ConnectivityTestService.testPort(
      host: host,
      port: textPort,
    );

    if (textResult.success) {
      await LogService.instance.info(
        'Text port test success: ${textResult.host}:${textResult.port}',
      );
    } else {
      await LogService.instance.error(
        'Text port test failed: ${textResult.host}:${textResult.port} -> ${textResult.message}',
      );
    }

    final fileResult = await ConnectivityTestService.testPort(
      host: host,
      port: filePort,
    );

    if (fileResult.success) {
      await LogService.instance.info(
        'File port test success: ${fileResult.host}:${fileResult.port}',
      );
    } else {
      await LogService.instance.error(
        'File port test failed: ${fileResult.host}:${fileResult.port} -> ${fileResult.message}',
      );
    }

    _showMessage('Connection test finished');
  }

  Future<void> _selfTest() async {
    await LogService.instance.info('Start self test to 127.0.0.1');
    await _testConnection('127.0.0.1');
  }

  Future<void> _copyReceivedText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _showMessage('Text copied');
  }

  Future<void> _saveReceivedText(ReceivedTextMessage msg) async {
    final dir = await SaveLocationService.instance
        .ensureSenderCategoryDirectory(
          senderName: msg.fromDeviceName,
          category: 'Text',
        );

    final fileName =
        'text_${msg.time.year.toString().padLeft(4, '0')}-'
        '${msg.time.month.toString().padLeft(2, '0')}-'
        '${msg.time.day.toString().padLeft(2, '0')}_'
        '${msg.time.hour.toString().padLeft(2, '0')}-'
        '${msg.time.minute.toString().padLeft(2, '0')}-'
        '${msg.time.second.toString().padLeft(2, '0')}.txt';

    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(msg.text, flush: true);

    await LogService.instance.info('Received text saved to ${file.path}');
    _showMessage('Text saved: ${file.path}');
  }

  Future<void> _editReceivedText(ReceivedTextMessage msg) async {
    final controller = TextEditingController(text: msg.text);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          child: Container(
            width: 820,
            height: 620,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit / Save Text',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TextField(
                    controller: controller,
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: controller.text),
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Edited text copied')),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final dir = await SaveLocationService.instance
                            .ensureSenderCategoryDirectory(
                              senderName: msg.fromDeviceName,
                              category: 'Text',
                            );

                        final now = DateTime.now();
                        final fileName =
                            'edited_text_'
                            '${now.year.toString().padLeft(4, '0')}-'
                            '${now.month.toString().padLeft(2, '0')}-'
                            '${now.day.toString().padLeft(2, '0')}_'
                            '${now.hour.toString().padLeft(2, '0')}-'
                            '${now.minute.toString().padLeft(2, '0')}-'
                            '${now.second.toString().padLeft(2, '0')}.txt';

                        final file = File(
                          '${dir.path}${Platform.pathSeparator}$fileName',
                        );

                        await file.writeAsString(controller.text, flush: true);

                        if (!mounted) return;
                        Navigator.of(context).pop();
                        _showMessage('Edited text saved: ${file.path}');
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _chooseSaveBasePath() async {
    await SaveLocationService.instance.chooseCustomBasePath();
    if (!mounted) return;
    setState(() {});
    _showMessage('Custom save path selected');
  }

  void _useDefaultSavePath() {
    SaveLocationService.instance.useDefault();
    setState(() {});
    _showMessage('Switched to default save path');
  }

  Widget _buildSavePathCard() {
    final isDefault = SaveLocationService.instance.useDefaultPath;
    final custom = SaveLocationService.instance.customBasePath;

    final shownPath = isDefault
        ? '${Directory.current.path}${Platform.pathSeparator}Received'
        : (custom ?? 'Not selected');

    final cachePath = '${Directory.current.path}${Platform.pathSeparator}Cache';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Save Path',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            isDefault ? 'Mode: Default Path' : 'Mode: Custom Path',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 6),
          SelectableText(shownPath),
          const SizedBox(height: 8),
          const Text(
            'Cache Folder',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          SelectableText(cachePath),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton(
                onPressed: _useDefaultSavePath,
                child: const Text('Use Default'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _chooseSaveBasePath,
                child: const Text('Choose Custom Folder'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReceivedTextTab() {
    if (_receivedMessages.isEmpty) {
      return const Center(child: Text('No text received yet'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _receivedMessages.length,
      itemBuilder: (context, index) {
        final msg = _receivedMessages[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  msg.fromDeviceName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${msg.fromIp} | ${msg.contentType}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 220),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: SelectableText(
                        msg.text,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _copyReceivedText(msg.text),
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _editReceivedText(msg),
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _saveReceivedText(msg),
                      icon: const Icon(Icons.save),
                      label: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReceivedStorageTab() {
    if (_receivedFiles.isEmpty && _receivedFolders.isEmpty) {
      return const Center(child: Text('No file or folder received yet'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_receivedFolders.isNotEmpty) ...[
          const Text(
            'Folders',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._receivedFolders.map((folder) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.folder),
                title: Text(folder.folderName),
                subtitle: SelectableText(
                  'From: ${folder.fromDeviceName} (${folder.fromIp})\n'
                  'Saved: ${folder.savedPath}',
                ),
                isThreeLine: true,
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
        if (_receivedFiles.isNotEmpty) ...[
          const Text(
            'Files',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._receivedFiles.map((file) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: Text(file.fileName),
                subtitle: SelectableText(
                  'From: ${file.fromDeviceName} (${file.fromIp})\n'
                  'Size: ${file.size} bytes\n'
                  'Saved: ${file.savedPath}',
                ),
                isThreeLine: true,
              ),
            );
          }),
        ],
      ],
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final deviceCount = _devices.length;
    final defaultHost = _devices.isNotEmpty ? _devices.first.ip : '';

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F8FB),
        body: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Container(
                    color: Colors.white,
                    child: const TabBar(
                      tabs: [
                        Tab(text: 'Logs'),
                        Tab(text: 'Received Text'),
                        Tab(text: 'Received Storage'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: LogPanel(
                            logs: _logs,
                            onCopyAll: _copyAllLogs,
                            onSaveLogs: _saveLogs,
                          ),
                        ),
                        _buildReceivedTextTab(),
                        _buildReceivedStorageTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 450,
              decoration: const BoxDecoration(
                color: Color(0xFFFDFDFD),
                border: Border(left: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lan Share',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Device: ${_buildDesktopName()}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'IP: $_localIp   Text: 40402   File: 40403   Online: $deviceCount',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      _buildSavePathCard(),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 210,
                        child: DeviceList(
                          devices: _devices,
                          onToggle: _toggleDevice,
                          onRemove: _removeDevice,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ManualDeviceBox(onAddDevice: _addManualDevice),
                      const SizedBox(height: 16),
                      ConnectivityTestBox(
                        defaultHost: defaultHost,
                        onTest: _testConnection,
                        onSelfTest: _selfTest,
                      ),
                      const SizedBox(height: 16),
                      DropPanel(
                        onPickFile: _pickAndSendFile,
                        onPickFolder: _pickAndSendFolder,
                      ),
                      const SizedBox(height: 16),
                      TextSendBox(
                        controller: _textController,
                        onSend: _sendText,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 240,
                        child: TransferQueue(tasks: _tasks),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
