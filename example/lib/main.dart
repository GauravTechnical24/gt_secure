import 'package:flutter/material.dart';
import 'package:gt_secure/gt_secure.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await secureStorage.init();
  runApp(const GtSecureExampleApp());
}

class GtSecureExampleApp extends StatelessWidget {
  const GtSecureExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GT Secure Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const SecureStorageDemo(),
    );
  }
}

class SecureStorageDemo extends StatefulWidget {
  const SecureStorageDemo({super.key});

  @override
  State<SecureStorageDemo> createState() => _SecureStorageDemoState();
}

class _SecureStorageDemoState extends State<SecureStorageDemo> {
  final _keyController = TextEditingController();
  final _valueController = TextEditingController();

  String _storedValue = '';
  List<String> _allKeys = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAllKeys();
  }

  Future<void> _loadAllKeys() async {
    setState(() => _isLoading = true);
    try {
      final keys = await secureStorage.getAllKeys();
      setState(() {
        _allKeys = keys;
      });
    } on SecureStorageException catch (e) {
      _showError('Failed to load keys: ${e.message}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveValue() async {
    final key = _keyController.text.trim();
    final value = _valueController.text.trim();

    if (key.isEmpty || value.isEmpty) {
      _showError('Please enter both key and value');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await secureStorage.setString(key, value);
      _keyController.clear();
      _valueController.clear();
      await _loadAllKeys();
      _showSuccess('Value saved securely!');
    } on SecureStorageException catch (e) {
      _showError('Failed to save: ${e.message}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getValue(String key) async {
    setState(() => _isLoading = true);
    try {
      final value = await secureStorage.getString(key);
      setState(() {
        _storedValue = value ?? 'No value found';
      });
    } on SecureStorageException catch (e) {
      _showError('Failed to retrieve: ${e.message}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteKey(String key) async {
    setState(() => _isLoading = true);
    try {
      await secureStorage.remove(key);
      await _loadAllKeys();
      setState(() {
        _storedValue = '';
      });
      _showSuccess('Key deleted successfully!');
    } on SecureStorageException catch (e) {
      _showError('Failed to delete: ${e.message}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text('Are you sure you want to delete all stored data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await secureStorage.clearAll();
      await _loadAllKeys();
      setState(() {
        _storedValue = '';
      });
      _showSuccess('All data cleared!');
    } on SecureStorageException catch (e) {
      _showError('Failed to clear: ${e.message}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showStats() async {
    try {
      final stats = await secureStorage.getStorageStats();
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Storage Statistics'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatRow('Total Keys', '${stats['totalKeys']}'),
              _buildStatRow('Total Size', '${stats['totalSizeBytes']} bytes'),
              _buildStatRow('Cache Size', '${stats['cacheSize']}'),
              _buildStatRow('Version', '${stats['version']}'),
              _buildStatRow('Initialized', '${stats['initialized']}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } on SecureStorageException catch (e) {
      _showError('Failed to get stats: ${e.message}');
    }
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green.shade700,
        ),
      );
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GT Secure Demo'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Storage Stats',
            onPressed: _showStats,
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Clear All',
            onPressed: _clearAll,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Input Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Store Secure Data',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _keyController,
                            decoration: const InputDecoration(
                              labelText: 'Key',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.key),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _valueController,
                            decoration: const InputDecoration(
                              labelText: 'Value',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.lock),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _saveValue,
                              icon: const Icon(Icons.save),
                              label: const Text('Save Securely'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Retrieved Value Section
                  if (_storedValue.isNotEmpty)
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Retrieved Value',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: SelectableText(
                                _storedValue,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Stored Keys Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Stored Keys (${_allKeys.length})',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                onPressed: _loadAllKeys,
                                tooltip: 'Refresh',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_allKeys.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'No keys stored yet.\nAdd some data above!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _allKeys.length,
                              separatorBuilder: (_, __) => const Divider(),
                              itemBuilder: (context, index) {
                                final key = _allKeys[index];
                                return ListTile(
                                  leading: const Icon(Icons.vpn_key),
                                  title: Text(key),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.visibility),
                                        tooltip: 'View Value',
                                        onPressed: () => _getValue(key),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete),
                                        tooltip: 'Delete',
                                        color: Colors.red,
                                        onPressed: () => _deleteKey(key),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}
