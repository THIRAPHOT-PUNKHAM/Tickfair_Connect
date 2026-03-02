import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firestore service providing complete queue and ticket management per PRD spec.
class DbService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Reference to the `events` collection.
  CollectionReference get events => _firestore.collection('events');

  /// Reference to the `queues` collection.
  CollectionReference get queues => _firestore.collection('queues');

  /// Reference to the `tickets` collection.
  CollectionReference get tickets => _firestore.collection('tickets');

  /// Reference to the `user_profiles` collection.
  CollectionReference get userProfiles => _firestore.collection('user_profiles');

  // ============= Event Management =============
  
  /// Get event details as a Map.
  Future<Map<String, dynamic>?> getEventData(String eventId) async {
    final doc = await events.doc(eventId).get();
    return doc.data() as Map<String, dynamic>?;
  }

  /// FR-E1: Get events stream for real-time display.
  Stream<QuerySnapshot<Map<String, dynamic>>> getEventsStream() {
    return events
        .where('status', isEqualTo: 'active')
        .snapshots()
        .cast<QuerySnapshot<Map<String, dynamic>>>();
  }

  /// Add an event document (admin only).
  Future<DocumentReference> addEvent(Map<String, dynamic> data) {
    return events.add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get event details by ID as DocumentSnapshot.
  Future<DocumentSnapshot> getEventById(String eventId) {
    return events.doc(eventId).get();
  }

  // ============= Queue Management =============
  
  /// FR-Q1: Join a queue for an event.
  Future<String> joinQueue(String eventId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    final existing = await queues
        .where('eventId', isEqualTo: eventId)
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('Already in queue for this event');
    }

    final queueDoc = await queues.add({
      'eventId': eventId,
      'userId': userId,
      'joinedAt': FieldValue.serverTimestamp(),
      'status': 'active',
      'position': 0, 
    });

    return queueDoc.id;
  }

  /// FR-Q3: Get current queue position for user in an event.
  Future<Map<String, dynamic>?> getQueuePosition(String queueEntryId) async {
    final doc = await queues.doc(queueEntryId).get();
    if (!doc.exists) return null;

    final data = doc.data() as Map<String, dynamic>;
    final eventId = data['eventId'];
    final joinedAt = data['joinedAt'] as Timestamp?;

    if (joinedAt == null) return null;

    int earlierCount = 0;
    try {
      final earlier = await queues
          .where('eventId', isEqualTo: eventId)
          .where('joinedAt', isLessThan: joinedAt)
          .where('status', isEqualTo: 'active')
          .count()
          .get();
      earlierCount = earlier.count ?? 0;
    } catch (_) {
      final snap = await queues
          .where('eventId', isEqualTo: eventId)
          .where('status', isEqualTo: 'active')
          .get();
      earlierCount = snap.docs.where((d) {
        final docData = d.data() as Map<String, dynamic>?;
        final docJoined = docData?['joinedAt'] as Timestamp?;
        if (docJoined == null) return false;
        return docJoined.compareTo(joinedAt) < 0;
      }).length;
    }

    return {
      'position': earlierCount + 1,
      'joinedAt': joinedAt,
      'status': data['status'] ?? 'active',
    };
  }

  /// FR-Q5: Cancel queue entry.
  Future<void> cancelQueueEntry(String queueEntryId) async {
    await queues.doc(queueEntryId).update({'status': 'cancelled'});
  }

  /// Debug helper.
  Future<String> createSampleEvent() async {
    final doc = await events.add({
      'name': 'Sample Event',
      'description': 'This event was created automatically for testing.',
      'venue': 'Demo Venue',
      'capacity': 100,
      'ticketsAvailable': 100,
      'dateTime': FieldValue.serverTimestamp(),
      'status': 'active',
    });
    return doc.id;
  }

  /// FR-Q? : Get active queue entry ID.
  Future<String?> getActiveQueueEntry(String eventId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    final existing = await queues
        .where('eventId', isEqualTo: eventId)
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (existing.docs.isEmpty) return null;
    return existing.docs.first.id;
  }

  /// Get real-time queue updates.
  Stream<QuerySnapshot> getQueueUpdatesStream(String eventId) {
    return queues
        .where('eventId', isEqualTo: eventId)
        .where('status', isEqualTo: 'active')
        .orderBy('joinedAt')
        .snapshots();
  }

  // ============= Ticket Management =============
  
  /// FR-T1: Reserve a ticket (Basic version).
  Future<String> reserveTicket(String eventId, String queueEntryId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    return await _firestore.runTransaction((tx) async {
      final eventRef = events.doc(eventId);
      final eventSnap = await tx.get(eventRef);
      
      if (!eventSnap.exists) throw Exception('Event not found');
      
      final eventData = eventSnap.data() as Map<String, dynamic>;
      final currentAvailable = (eventData['ticketsAvailable'] ?? 0) as num;

      if (currentAvailable <= 0) throw Exception('Sorry, no tickets available.');

      final ticketRef = tickets.doc();
      tx.set(ticketRef, {
        'eventId': eventId,
        'userId': userId,
        'queueEntryId': queueEntryId,
        'ticketId': 'TKT-${DateTime.now().millisecondsSinceEpoch}',
        'status': 'reserved',
        'reservedAt': FieldValue.serverTimestamp(),
      });

      tx.update(queues.doc(queueEntryId), {'status': 'completed'});
      tx.update(eventRef, {'ticketsAvailable': currentAvailable - 1});

      return ticketRef.id;
    });
  }

  /// Reserve a ticket with seat selection and price + Auto-decrement ticketsAvailable.
  Future<String> reserveTicketWithSeat(
    String eventId,
    String queueEntryId,
    String seatLabel,
    int price,
  ) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    // Use Transaction to ensure atomicity (Check available -> Create ticket -> Update event)
    return await _firestore.runTransaction((tx) async {
      final eventRef = events.doc(eventId);
      final eventSnap = await tx.get(eventRef);
      
      if (!eventSnap.exists) throw Exception('Event not found');
      
      final eventData = eventSnap.data() as Map<String, dynamic>;
      final currentAvailable = (eventData['ticketsAvailable'] ?? 0) as num;

      // 1. Check if tickets are still available
      if (currentAvailable <= 0) {
        throw Exception('Sorry, no tickets available for this event.');
      }

      // 2. Check if the user already has a ticket
      final existingQuery = await tickets
          .where('eventId', isEqualTo: eventId)
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'reserved')
          .limit(1)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        throw Exception('You already have a ticket for this event.');
      }

      // 3. Create the ticket document
      final ticketRef = tickets.doc();
      tx.set(ticketRef, {
        'eventId': eventId,
        'userId': userId,
        'queueEntryId': queueEntryId,
        'ticketId': 'TKT-${DateTime.now().millisecondsSinceEpoch}',
        'seatLabel': seatLabel,
        'price': price,
        'status': 'reserved',
        'reservedAt': FieldValue.serverTimestamp(),
      });

      // 4. Update queue status
      tx.update(queues.doc(queueEntryId), {'status': 'completed'});

      // 5. DECREMENT ticketsAvailable in the event document
      tx.update(eventRef, {'ticketsAvailable': currentAvailable - 1});

      return ticketRef.id;
    });
  }

  /// Get all booked seat labels for a specific event
  Future<List<String>> getBookedSeats(String eventId) async {
    final snap = await tickets
        .where('eventId', isEqualTo: eventId)
        .where('status', isEqualTo: 'reserved')
        .get();
        
    final bookedSeats = <String>[];
    for (var doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['seatLabel'] != null) {
        bookedSeats.add(data['seatLabel'].toString());
      }
    }
    return bookedSeats;
  }

  /// Get ticket confirmation for specific event.
  Future<Map<String, dynamic>?> getUserTicketForEvent(String eventId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');
    final snap = await tickets
        .where('eventId', isEqualTo: eventId)
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'reserved')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final data = snap.docs.first.data() as Map<String, dynamic>;
    data['docId'] = snap.docs.first.id;
    return data;
  }

  /// Get ticket details by ID.
  Future<Map<String, dynamic>?> getTicketDetails(String ticketId) async {
    final doc = await tickets.doc(ticketId).get();
    if (!doc.exists) return null;
    return doc.data() as Map<String, dynamic>;
  }

  // ============= User Profile =============
  
  /// FR-A3: Update user profile.
  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    await userProfiles.doc(userId).set(
      {...data, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  /// Get user profile.
  Future<Map<String, dynamic>?> getUserProfile() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return null;

    final doc = await userProfiles.doc(userId).get();
    return doc.exists ? doc.data() as Map<String, dynamic> : null;
  }
}