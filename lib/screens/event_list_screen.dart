import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/db_service.dart';
import '../theme/app_theme.dart';
import 'event_detail_screen.dart';

class EventListScreen extends StatefulWidget {
  static const routeName = '/events';
  const EventListScreen({super.key});

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'dateTime'; // 'dateTime' or 'availability'

  @override
  Widget build(BuildContext context) {
    final db = context.read<DbService>();
    final auth = context.read<AuthService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Events'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final navigator = Navigator.of(context);
              await auth.signOut();
              if (!mounted) return;
              navigator.pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: AppTheme.primaryColor,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    hintText: 'Search by event name or venue...',
                    prefixIcon: const Icon(Icons.search, color: AppTheme.primaryColor),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Sort Options
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildSortButton('Upcoming', 'dateTime'),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Events List
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: db.getEventsStream(),
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                      ],
                    ),
                  );
                }
                final docs = snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                final filtered = docs.where((event) {
                  final data = event.data();
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final venue = (data['venue'] ?? '').toString().toLowerCase();
                  final description = (data['description'] ?? '').toString().toLowerCase();
                  
                  return name.contains(_searchQuery) || 
                         venue.contains(_searchQuery) ||
                         description.contains(_searchQuery);
                }).toList();

                // Sort the events
                filtered.sort((a, b) {
                  if (_sortBy == 'dateTime') {
                    final dateA = (a.data()['dateTime'] as Timestamp?)?.toDate() ?? DateTime(2999);
                    final dateB = (b.data()['dateTime'] as Timestamp?)?.toDate() ?? DateTime(2999);
                    return dateA.compareTo(dateB);
                  } else if (_sortBy == 'availability') {
                    final availA = (a.data()['ticketsAvailable'] ?? 0) as int;
                    final availB = (b.data()['ticketsAvailable'] ?? 0) as int;
                    return availB.compareTo(availA); // Sort by availability descending
                  }
                  return 0;
                });

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.event_note, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'No events available',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final event = filtered[i];
                    final data = event.data();
                    final eventId = event.id;
                    final name = data['name'] ?? 'Untitled Event';
                    final venue = data['venue'] ?? 'Location TBA';
                    final capacity = data['capacity'] ?? 0;
                    final available = data['ticketsAvailable'] ?? 0;
                    final dateTime = data['dateTime']?.toDate();
                    final date = dateTime != null
                        ? '${dateTime.day}/${dateTime.month}/${dateTime.year}'
                        : 'TBA';

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 2,
                      child: InkWell(
                        onTap: () {
                          // include event id in the path to support deep links
                          Navigator.pushNamed(
                            ctx,
                            '${EventDetailScreen.routeName}/$eventId',
                            arguments: eventId,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: available > 0
                                          ? AppTheme.successColor.withAlpha((0.2 * 255).round())
                                          : AppTheme.errorColor.withAlpha((0.2 * 255).round()),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      available > 0 ? '$available left' : 'Sold out',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: available > 0
                                            ? AppTheme.successColor
                                            : AppTheme.errorColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      venue,
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    date,
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              LinearProgressIndicator(
                                value: capacity > 0 ? (capacity - available) / capacity : 0,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppTheme.primaryColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '$capacity tickets',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  Text(
                                    '${((capacity - available) / capacity * 100).toStringAsFixed(0)}% sold',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      // floatingActionButton: kDebugMode
      //     ? FloatingActionButton(
      //         tooltip: 'Create sample event',
      //         child: const Icon(Icons.event),
      //         onPressed: () async {
      //           String message;
      //           try {
      //             final id = await db.createSampleEvent();
      //             message = 'Created sample event $id';
      //           } catch (e) {
      //             message = 'Error: ${e.toString()}';
      //           }
      //           if (mounted) {
      //             // ignore: use_build_context_synchronously
      //             ScaffoldMessenger.of(context).showSnackBar(
      //               SnackBar(content: Text(message)),
      //             );
      //           }
      //         },
      //       )
      //     : null,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildSortButton(String label, String value) {
    final isSelected = _sortBy == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : AppTheme.primaryColor,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _sortBy = value);
      },
      backgroundColor: Colors.white,
      selectedColor: AppTheme.primaryColor,
      side: BorderSide(
        color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
      ),
    );
  }
}
