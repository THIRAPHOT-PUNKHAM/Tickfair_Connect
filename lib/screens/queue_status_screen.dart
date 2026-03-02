import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/db_service.dart';
import '../theme/app_theme.dart';

class QueueStatusScreen extends StatefulWidget {
  static const routeName = '/queue-status';

  const QueueStatusScreen({super.key});

  @override
  State<QueueStatusScreen> createState() => _QueueStatusScreenState();
}

class _QueueStatusScreenState extends State<QueueStatusScreen> {
  bool _cancelling = false;

  Future<void> _cancelQueue(String queueId) async {
    setState(() => _cancelling = true);
    try {
      final db = context.read<DbService>();
      await db.cancelQueueEntry(queueId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Queue cancelled')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _reserveTicket(String eventId, String queueId) async {
    try {
      if (mounted) {
        Navigator.pushNamed(
          context,
          '/seat-selection',
          arguments: {'eventId': eventId, 'queueId': queueId},
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final eventId = args?['eventId'] as String?;
    final queueId = args?['queueId'] as String?;

    if (eventId == null || queueId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Queue Status')),
        body: const Center(child: Text('Invalid queue data')),
      );
    }

    final db = context.read<DbService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Queue Status')),
      body: FutureBuilder(
        future: db.getQueuePosition(queueId),
        builder: (ctx, posSnapshot) {
          if (posSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (posSnapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Failed to load queue status'),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Text(
                      posSnapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: () => setState(() {}),
                        child: const Text('Retry'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          if (!posSnapshot.hasData || posSnapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Queue entry not found'),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          final posData = posSnapshot.data!;
          final position = posData['position'] as int? ?? 0;
          final isReady = position == 1;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  // Position Circle
                  Center(
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isReady
                            ? AppTheme.successColor.withAlpha((0.1 * 255).round())
                            : AppTheme.primaryColor.withAlpha((0.1 * 255).round()),
                        border: Border.all(
                          color: isReady ? AppTheme.successColor : AppTheme.primaryColor,
                          width: 3,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$position',
                            style: TextStyle(
                              fontSize: 64,
                              fontWeight: FontWeight.bold,
                              color: isReady ? AppTheme.successColor : AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isReady ? 'In Position' : 'In Queue',
                            style: TextStyle(
                              fontSize: 14,
                              color: isReady ? AppTheme.successColor : AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Queue Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildQueueInfo(
                          icon: Icons.queue,
                          label: 'Your Position',
                          value: position == 1 ? 'Next!' : 'Position #$position',
                          isHighlight: isReady,
                        ),
                        const SizedBox(height: 16),
                        _buildQueueInfo(
                          icon: Icons.access_time,
                          label: 'Estimated Wait',
                          value: position == 1 ? 'Ready to reserve' : '~${(position - 1) * 2} min',
                        ),
                        const SizedBox(height: 16),
                        _buildQueueInfo(
                          icon: Icons.warning,
                          label: 'Status',
                          value: position == 1 ? 'Ready to reserve' : 'Please wait your turn',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Info Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withAlpha((0.1 * 255).round()),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.primaryColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Fair Queue System',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your position is determined by the time you joined. Please keep the app open to maintain your spot in the queue.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Reserve Button (enabled when position == 1)
                  if (isReady)
                    ElevatedButton.icon(
                      onPressed: () => _reserveTicket(eventId, queueId),
                      icon: const Icon(Icons.confirmation_number),
                      label: const Text('Reserve Your Ticket'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    )
                  else
                    ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                      child: const Text('Waiting for your turn...'),
                    ),
                  const SizedBox(height: 12),
                  // Cancel Button
                  TextButton(
                    onPressed: _cancelling ? null : () => _cancelQueue(queueId),
                    child: Text(
                      _cancelling ? 'Cancelling...' : 'Cancel Queue',
                      style: const TextStyle(color: AppTheme.errorColor),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQueueInfo({
    required IconData icon,
    required String label,
    required String value,
    bool isHighlight = false,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: isHighlight ? AppTheme.successColor : AppTheme.primaryColor,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isHighlight ? AppTheme.successColor : Colors.black,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
