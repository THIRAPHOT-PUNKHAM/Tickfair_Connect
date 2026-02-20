import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BookingPage extends StatefulWidget {
  final String eventId;
  final String userId;
  final int queueNumber;
  const BookingPage({super.key, required this.eventId, required this.userId, required this.queueNumber});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  String selectedZone = "Zone A (2,500 THB)";
  String selectedRow = "A"; // ตัวแปรเก็บแถว
  String selectedSeat = "1"; // ตัวแปรเก็บเลขที่นั่ง
  bool loading = false;

  void _confirm() async {
    setState(() => loading = true);
    await FirebaseFirestore.instance.collection('events').doc(widget.eventId).collection('queues').doc(widget.userId).update({
      'status': 'completed',
      'selectedZone': selectedZone,
      'selectedRow': selectedRow, // บันทึกแถว
      'selectedSeat': selectedSeat, // บันทึกเลขที่นั่ง
      'bookedAt': FieldValue.serverTimestamp(),
    });
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("จองสำเร็จ! กรุณาตรวจสอบที่หน้าตั๋วของฉัน")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("เลือกที่นั่ง")),
      body: SingleChildScrollView( // ป้องกันหน้าจอล้น
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("คิวที่ #${widget.queueNumber}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            const Text("1. เลือกโซน"),
            DropdownButton<String>(
              isExpanded: true,
              value: selectedZone,
              items: ["Zone A (2,500 THB)", "Zone B (1,500 THB)", "Zone C (800 THB)"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => selectedZone = v!),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("2. เลือกแถว"),
                      DropdownButton<String>(
                        isExpanded: true,
                        value: selectedRow,
                        items: ["A", "B", "C", "D", "E"].map((e) => DropdownMenuItem(value: e, child: Text("แถว $e"))).toList(),
                        onChanged: (v) => setState(() => selectedRow = v!),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("3. เลขที่นั่ง"),
                      DropdownButton<String>(
                        isExpanded: true,
                        value: selectedSeat,
                        items: List.generate(10, (index) => "${index + 1}").map((e) => DropdownMenuItem(value: e, child: Text("ที่นั่ง $e"))).toList(),
                        onChanged: (v) => setState(() => selectedSeat = v!),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 60), 
                backgroundColor: Colors.green, 
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
              ),
              onPressed: loading ? null : _confirm,
              child: loading ? const CircularProgressIndicator(color: Colors.white) : const Text("ยืนยันการจองที่นั่ง"),
            ),
          ],
        ),
      ),
    );
  }
}