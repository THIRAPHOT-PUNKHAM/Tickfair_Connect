import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/db_service.dart';
import '../theme/app_theme.dart';

class SeatSelectionScreen extends StatefulWidget {
  static const routeName = '/seat-selection';
  const SeatSelectionScreen({super.key});

  @override
  State<SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  static const int totalRows = 20;
  static const int seatsPerRow = 50;

  int? selectedSeatIndex;
  int? selectedRow;
  int _eventPrice = 0; // เก็บราคาที่ดึงมาจาก Firebase
  bool _reserving = false;

  Map<String, dynamic>? _existingTicket;
  List<String> _bookedSeats = [];
  bool _checkingTicket = true;
  bool _initialized = false;

  // แปลง Index เป็น Label เช่น R1-S1
  String _getSeatLabel(int index) {
    int row = (index ~/ seatsPerRow) + 1;
    int seat = (index % seatsPerRow) + 1;
    return 'R$row-S$seat';
  }

  Future<void> _reserveWithSeat(String eventId, String queueId) async {
    if (selectedSeatIndex == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a seat')));
      return;
    }

    setState(() => _reserving = true);
    try {
      final db = context.read<DbService>();
      final seatLabel = _getSeatLabel(selectedSeatIndex!);

      // ส่งข้อมูลที่นั่ง พร้อมราคาที่ดึงมาจาก Firebase (_eventPrice)
      final ticketId = await db.reserveTicketWithSeat(
        eventId,
        queueId,
        seatLabel,
        _eventPrice,
      );

      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/reservation',
          arguments: {'eventId': eventId, 'ticketId': ticketId},
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _reserving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final eventId = args?['eventId'] as String?;
    final queueId = args?['queueId'] as String?;

    if (!_initialized) {
      _initialized = true;
      if (eventId != null) {
        final db = context.read<DbService>();

        // ดึงทั้งข้อมูลตั๋วเดิม และข้อมูลราคาจาก Event ไปพร้อมกัน
        Future.wait([
              db.getUserTicketForEvent(eventId),
              db.getEventData(eventId), // ต้องมีฟังก์ชันนี้ใน DbService เพื่อดึงฟิลด์ price
              db.getBookedSeats(eventId), // Get all booked seats for the event
            ])
            .then((results) {
              if (mounted) {
                setState(() {
                  _existingTicket = results[0] as Map<String, dynamic>?;
                  final eventData = results[1] as Map<String, dynamic>?;
                  // ดึงค่า price จาก Firebase (ถ้าไม่มีให้เป็น 0)
                  _eventPrice = eventData?['price'] ?? 0;
                  _bookedSeats = results[2] as List<String>;
                });
              }
            })
            .catchError((e) {
              debugPrint('Error fetching initialization data: $e');
            })
            .whenComplete(() {
              if (mounted) setState(() => _checkingTicket = false);
            });
      } else {
        _checkingTicket = false;
      }
    }

    if (eventId == null || queueId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Seat Selection')),
        body: const Center(child: Text('Invalid data')),
      );
    }

    Widget bodyContent;
    if (_checkingTicket) {
      bodyContent = const Center(child: CircularProgressIndicator());
    } else if (_existingTicket != null) {
      bodyContent = _buildAlreadyBookedView(eventId, queueId, _existingTicket!);
    } else {
      bodyContent = SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Row Selection
              const Text(
                'Select Row',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButton<int>(
                value: selectedRow,
                hint: const Text('All Rows'),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<int>(
                    value: null,
                    child: Text('All Rows'),
                  ),
                  ...List.generate(totalRows, (i) => i + 1).map(
                    (r) =>
                        DropdownMenuItem<int>(value: r, child: Text('Row $r')),
                  ),
                ],
                onChanged: (r) => setState(() {
                  selectedRow = r;
                  selectedSeatIndex = null;
                }),
              ),
              const SizedBox(height: 32),

              // 2. Seat Selection Grid
              const Text(
                'Select Your Seat',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                height: 4,
                width: double.infinity,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 20),
              _buildSeatGrid(),

              const SizedBox(height: 24),

              // 3. Selection Summary (โชว์แค่เลขที่นั่ง ไม่โชว์ราคา)
              if (selectedSeatIndex != null) _buildSelectionSummary(),

              const SizedBox(height: 32),

              // 4. Confirm Button
              // ส่วนของ UI ปุ่มที่คุณส่งมา
              _reserving
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: selectedSeatIndex == null
                            ? null
                            : () => _reserveWithSeat(
                                eventId!,
                                queueId!,
                              ), // เรียกฟังก์ชันจอง
                        icon: const Icon(Icons.check),
                        label: const Text('Confirm Seat Selection'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Seat Selection')),
      body: bodyContent,
    );
  }

  Widget _buildSeatGrid() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 10,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: (selectedRow == null)
            ? (totalRows * seatsPerRow)
            : seatsPerRow,
        itemBuilder: (ctx, idx) {
          int index = (selectedRow == null)
              ? idx
              : ((selectedRow! - 1) * seatsPerRow) + idx;
          bool isSelected = selectedSeatIndex == index;
          String seatLabel = _getSeatLabel(index);
          bool isBooked = _bookedSeats.contains(seatLabel);
          
          return GestureDetector(
            onTap: isBooked ? null : () => setState(() => selectedSeatIndex = index),
            child: Container(
              decoration: BoxDecoration(
                color: isBooked
                    ? Colors.grey.shade400
                    : isSelected
                        ? AppTheme.successColor
                        : AppTheme.primaryColor.withOpacity(0.1),
                border: Border.all(
                  color: isBooked
                      ? Colors.grey.shade500
                      : isSelected
                          ? AppTheme.successColor
                          : AppTheme.primaryColor.withOpacity(0.3),
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: isBooked
                    ? const Icon(Icons.close, size: 12, color: Colors.white)
                    : Text(
                        (index + 1).toString(),
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected ? Colors.white : AppTheme.primaryColor,
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectionSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.successColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_seat, color: AppTheme.successColor),
          const SizedBox(width: 12),
          Text(
            'Selected Seat: ${_getSeatLabel(selectedSeatIndex!)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.successColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlreadyBookedView(
    String eventId,
    String queueId,
    Map<String, dynamic> ticket,
  ) {
    final seat = ticket['seatLabel'] ?? 'N/A';
    final docId = ticket['docId'] ?? '';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle,
            size: 60,
            color: AppTheme.successColor,
          ),
          const SizedBox(height: 16),
          const Text(
            'You have already reserved a seat',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text('Seat: $seat', style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.pushReplacementNamed(
                context,
                '/reservation',
                arguments: {'eventId': eventId, 'ticketId': docId},
              );
            },
            child: const Text('View Ticket'),
          ),
        ],
      ),
    );
  }
}
