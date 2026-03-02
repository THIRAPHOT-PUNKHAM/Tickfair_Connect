import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/db_service.dart';
import '../theme/app_theme.dart';

class EventDetailScreen extends StatefulWidget {
  static const routeName = '/event-detail';

  /// optional event id that can be provided via constructor or route args
  final String? eventId;

  const EventDetailScreen({super.key, this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _joining = false;
  String? _error;

  Future<void> _joinQueue(String eventId) async {
    setState(() {
      _joining = true;
      _error = null;
    });
    final db = context.read<DbService>();
    try {
      final queueId = await db.joinQueue(eventId);
      if (mounted) {
        Navigator.pushNamed(
          context,
          '/queue-status',
          arguments: {'eventId': eventId, 'queueId': queueId},
        );
      }
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (msg == 'Already in queue for this event') {
        // fetch existing entry and go to status screen instead
        try {
          final existingId = await db.getActiveQueueEntry(eventId);
          if (existingId != null && mounted) {
            Navigator.pushNamed(
              context,
              '/queue-status',
              arguments: {'eventId': eventId, 'queueId': existingId},
            );
            return;
          }
        } catch (_) {
          // ignore and show error below
        }
      }
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // try constructor value first (for programmatic navigation),
    // otherwise fall back to arguments or url path name
    final route = ModalRoute.of(context)!;
    String? eventId = widget.eventId;
    // prefer null-aware assignment instead of explicit if
    eventId ??= route.settings.arguments as String?;
    if (eventId == null) {
      // for web deep links the path may include the id
      final name = route.settings.name;
      if (name != null && name.startsWith('/event-detail/')) {
        eventId = name.split('/event-detail/').last;
      }
    }
    final db = context.read<DbService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Event Details')),
      body: eventId == null
          ? const Center(child: Text('Event not found'))
          : FutureBuilder(
              future: Future.wait([
                db.getEventById(eventId),
                db.getUserTicketForEvent(eventId),
              ]),
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        const Text('Event not found'),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Go Back'),
                        ),
                      ],
                    ),
                  );
                }

                final eventSnap = snapshot.data![0] as DocumentSnapshot;
                if (!eventSnap.exists) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        const Text('Event not found'),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Go Back'),
                        ),
                      ],
                    ),
                  );
                }

                final data = eventSnap.data() as Map<String, dynamic>;
                final userTicket = snapshot.data![1] as Map<String, dynamic>?;
                final name = data['name'] ?? 'Untitled';
                final description = data['description'] ?? 'No description';
                final venue = data['venue'] ?? 'Location TBA';
                final capacity = data['capacity'] ?? 0;
                final available = data['ticketsAvailable'] ?? 0;
                final price = data['price'] ?? 0;
                // price value is no longer shown on this screen
                // final price = data['price'] ?? 'Free';
                final dateTime = data['dateTime']?.toDate();
                final date = dateTime != null
                    ? '${dateTime.day}/${dateTime.month}/${dateTime.year}'
                    : 'TBA';
                final time = dateTime != null
                    ? '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}'
                    : 'TBA';

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryColor,
                              AppTheme.accentColor,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(
                                  (0.3 * 255).round(),
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                available > 0
                                    ? '$available Tickets Left'
                                    : 'Sold Out',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Event Info
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date & Time
                            _buildInfoSection(
                              icon: Icons.calendar_today,
                              label: 'Date & Time',
                              value: '$date at $time',
                            ),
                            const SizedBox(height: 16),
                            // Location
                            _buildInfoSection(
                              icon: Icons.location_on,
                              label: 'Venue',
                              value: venue,
                            ),
                            const SizedBox(height: 16),
                            _buildInfoSection(
                              icon: Icons.attach_money,
                              label: 'price',
                              value: '$price Baht',
                            ),
                            const SizedBox(height: 16),
                            // Ticket Info
                            _buildInfoSection(
                              icon: Icons.confirmation_number,
                              label: 'Tickets Available',
                              value: '$available / $capacity',
                            ),
                            const SizedBox(height: 16),
                            // Description
                            const Text(
                              'About Event',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              description,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Ticket Status
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: available > 0
                                    ? AppTheme.successColor.withAlpha(
                                        (0.1 * 255).round(),
                                      )
                                    : AppTheme.errorColor.withAlpha(
                                        (0.1 * 255).round(),
                                      ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: available > 0
                                      ? AppTheme.successColor
                                      : AppTheme.errorColor,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    available > 0
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color: available > 0
                                        ? AppTheme.successColor
                                        : AppTheme.errorColor,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      (available > 0 && capacity > 0)
                                          ? '${((capacity - available) / capacity * 100).toStringAsFixed(2)}% tickets sold'
                                          : (available == 0 && capacity > 0)
                                          ? 'All tickets are sold out'
                                          : 'Calculating...',
                                      style: TextStyle(
                                        color: available > 0
                                            ? AppTheme.successColor
                                            : AppTheme.errorColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Error Message
                            if (_error != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.errorColor.withAlpha(
                                    (0.1 * 255).round(),
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppTheme.errorColor,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: AppTheme.errorColor,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: const TextStyle(
                                          color: AppTheme.errorColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 24),
                            // Booking Info Box
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withAlpha(
                                  (0.1 * 255).round(),
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.info_outline,
                                        color: AppTheme.primaryColor,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          available > 0
                                              ? 'Join our fair queue to book your ticket'
                                              : 'This event is sold out',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.primaryColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (available > 0) ...[
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Your position in the queue will be determined by when you join. When your turn comes, you\'ll be able to complete your booking.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Booking / Booked Button
                            userTicket != null
                                ? SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        final docId = userTicket['docId'];
                                        if (docId != null) {
                                          Navigator.pushNamed(
                                            context,
                                            '/reservation',
                                            arguments: {
                                              'eventId': eventId,
                                              'ticketId': docId,
                                            },
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.confirmation_number),
                                      label: const Text('View Ticket'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        backgroundColor: AppTheme.successColor,
                                      ),
                                    ),
                                  )
                                : (_joining
                                      ? const Center(
                                          child: CircularProgressIndicator(),
                                        )
                                      : SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            onPressed: available > 0
                                                ? () => _joinQueue(eventId!)
                                                : null,
                                            icon: const Icon(
                                              Icons.confirmation_number,
                                            ),
                                            label: const Text(
                                              'Book Ticket - Join Queue',
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 14,
                                                  ),
                                              backgroundColor: available > 0
                                                  ? AppTheme.primaryColor
                                                  : Colors.grey.shade400,
                                            ),
                                          ),
                                        )),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildInfoSection({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 24),
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
