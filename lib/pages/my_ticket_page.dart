import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MyTicketPage extends StatelessWidget {
  final String userId;
  final String eventId; // รับค่า eventId โดยตรงจากหน้าอื่น

  const MyTicketPage({super.key, required this.userId, required this.eventId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple,
      appBar: AppBar(
        title: const Text("E-Ticket", style: TextStyle(color: Colors.white)), 
        backgroundColor: Colors.transparent, 
        iconTheme: const IconThemeData(color: Colors.white)
      ),
      body: StreamBuilder<DocumentSnapshot>(
        // ดึงข้อมูลกิจกรรม (เช่น ชื่อกิจกรรม)
        stream: FirebaseFirestore.instance.collection('events').doc(eventId).snapshots(),
        builder: (context, evSnap) {
          if (!evSnap.hasData || !evSnap.data!.exists) return const Center(child: CircularProgressIndicator());
          var event = evSnap.data!;
          
          return StreamBuilder<DocumentSnapshot>(
            // ดึงข้อมูลการจองของผู้ใช้ (โซน แถว ที่นั่ง)
            stream: FirebaseFirestore.instance.collection('events').doc(eventId).collection('queues').doc(userId).snapshots(),
            builder: (context, qSnap) {
              if (!qSnap.hasData || !qSnap.data!.exists) {
                return const Center(child: Text("ไม่พบข้อมูลตั๋ว", style: TextStyle(color: Colors.white)));
              }
              var queue = qSnap.data!;
              
              return Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ชื่อกิจกรรม
                      Text(event['name'] ?? 'กิจกรรม', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const Divider(height: 40),
                      
                      // รายละเอียดที่นั่ง
                      _row("Zone", queue['selectedZone'] ?? 'ไม่ได้ระบุ'),
                      
                      // --- เพิ่มแถวที่นั่งและหมายเลขที่นั่งแสดงผลตรงนี้ ---
                      _row("Row", queue['selectedRow'] ?? '-'),
                      _row("Seat No.", queue['selectedSeat'] ?? '-'),
                      // -------------------------------------------

                      _row("Queue", "#${queue['queueNumber']}"),
                      _row("Status", "Confirmed", color: Colors.green),
                      
                      const SizedBox(height: 30),
                      
                      // ส่วนของ QR Code จำลอง
                      const Icon(Icons.qr_code_2, size: 150),
                      const SizedBox(height: 10),
                      const Text("SCAN TO ENTER", style: TextStyle(letterSpacing: 2, color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Widget ตัวช่วยสำหรับสร้างแถวข้อมูลในตั๋ว
  Widget _row(String label, String value, {Color color = Colors.black}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)), 
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color))
        ],
      ),
    );
  }
}