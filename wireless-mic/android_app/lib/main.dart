import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'audio_provider.dart';

void main() {
  runApp(const WirelessMicApp());
}

class WirelessMicApp extends StatelessWidget {
  const WirelessMicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AudioProvider(),
      child: MaterialApp(
        title: 'Wireless Microphone',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const HomePage(),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _ipController = TextEditingController(
    text: '192.168.1.100',
  );

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wireless Microphone'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Consumer<AudioProvider>(
        builder: (context, provider, child) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Status Indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(provider.status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getStatusColor(provider.status),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStatusIcon(provider.status),
                        color: _getStatusColor(provider.status),
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getStatusText(provider.status),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(provider.status),
                            ),
                          ),
                          if (provider.errorMessage != null)
                            Text(
                              provider.errorMessage!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                // IP Address Input
                TextField(
                  controller: _ipController,
                  decoration: InputDecoration(
                    labelText: 'Server IP Address',
                    hintText: '192.168.1.100',
                    prefixIcon: const Icon(Icons.ip),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabled: !provider.isStreaming,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => provider.setIpAddress(value),
                ),
                const SizedBox(height: 32),
                // Start/Stop Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: provider.isStreaming ? null : () => _startStreaming(context),
                      icon: const Icon(Icons.mic),
                      label: const Text('START'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: provider.isStreaming ? () => _stopStreaming(context) : null,
                      icon: const Icon(Icons.stop),
                      label: const Text('STOP'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Info Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Audio Settings',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow('Sample Rate', '48000 Hz'),
                        _buildInfoRow('Bit Depth', '16-bit'),
                        _buildInfoRow('Channels', 'Mono'),
                        _buildInfoRow('Protocol', 'UDP'),
                        _buildInfoRow('Port', '55555'),
                        _buildInfoRow('Chunk Size', '4800 bytes (~100ms)'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'streaming':
        return Colors.red;
      case 'ready':
        return Colors.green;
      case 'error':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'streaming':
        return Icons.fiber_manual_record;
      case 'ready':
        return Icons.pause_circle_outline;
      case 'error':
        return Icons.error_outline;
      default:
        return Icons.help_outline;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'streaming':
        return '🔴 Streaming';
      case 'ready':
        return '⏹️ Ready';
      case 'error':
        return '⚠️ Error';
      default:
        return 'Unknown';
    }
  }

  Future<void> _startStreaming(BuildContext context) async {
    final provider = context.read<AudioProvider>();
    await provider.startStreaming();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          provider.status == 'streaming' 
            ? 'Streaming started successfully' 
            : 'Failed to start: ${provider.errorMessage}',
        ),
        backgroundColor: provider.status == 'streaming' ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _stopStreaming(BuildContext context) async {
    final provider = context.read<AudioProvider>();
    await provider.stopStreaming();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Streaming stopped'),
        backgroundColor: Colors.grey,
      ),
    );
  }
}
