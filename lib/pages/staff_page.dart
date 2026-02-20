import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StaffPage extends StatefulWidget {
  final String eventId;
  const StaffPage({super.key, required this.eventId});

  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> {

  // ฟังก์ชันเรียกคิวถัดไป
  Future<void> _nextQueue(int current) async {
    await FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .update({
      'currentServing': current + 1,
    });
  }

  Future<void> _logout() async {
  try {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    // ปิด StaffPage ออกก่อน
    Navigator.of(context).pop();

  } catch (e) {
    debugPrint("Logout Error: $e");
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Staff Control Panel",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ออกจากระบบ',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("ออกจากระบบ"),
                  content: const Text(
                      "คุณต้องการออกจากระบบ Staff ใช่หรือไม่?"),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("ยกเลิก")),
                    TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _logout(); // เรียก logout
                        },
                        child: const Text("ยืนยัน",
                            style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
            },
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('events')
            .doc(widget.eventId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          var data = snapshot.data!.data() as Map<String, dynamic>?;
          int current = data?['currentServing'] ?? 0;
          int last = data?['lastQueueNumber'] ?? 0;
          int max = data?['maxCapacity'] ?? 100;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    const Text("ลำดับคิวที่กำลังเรียก",
                        style:
                            TextStyle(fontSize: 16, color: Colors.grey)),
                    Text("$current",
                        style: const TextStyle(
                            fontSize: 80,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                            height: 1.2)),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(15),
                      margin:
                          const EdgeInsets.symmetric(horizontal: 30),
                      decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius:
                              BorderRadius.circular(15),
                          border: Border.all(
                              color: Colors.grey.shade300)),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceAround,
                        children: [
                          _statusItem("จองแล้ว", "$last"),
                          _statusItem("ทั้งหมด", "$max"),
                          _statusItem(
                              "คงเหลือ", "${max - last}"),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.campaign),
                      label: const Text("เรียกคิวถัดไป",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 40,
                                  vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(30))),
                      onPressed: current < last
                          ? () => _nextQueue(current)
                          : null,
                    ),
                  ],
                ),
              ),
              const Divider(thickness: 1, height: 1),
              Container(
                padding: const EdgeInsets.all(10),
                width: double.infinity,
                color: Colors.indigo.withOpacity(0.05),
                child: const Text("📋 รายการจองทั้งหมด",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo)),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('events')
                      .doc(widget.eventId)
                      .collection('queues')
                      .orderBy('queueNumber')
                      .snapshots(),
                  builder: (context, qSnap) {
                    if (!qSnap.hasData) {
                      return const Center(
                          child:
                              CircularProgressIndicator());
                    }

                    if (qSnap.data!.docs.isEmpty) {
                      return const Center(
                          child: Text(
                              "ยังไม่มีข้อมูลการจอง",
                              style: TextStyle(
                                  color: Colors.grey)));
                    }

                    return ListView.separated(
                      padding:
                          const EdgeInsets.only(bottom: 20),
                      itemCount: qSnap.data!.docs.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        var qDoc =
                            qSnap.data!.docs[index];
                        var qData =
                            qDoc.data() as Map<String, dynamic>;
                        int qNum =
                            qData['queueNumber'] ?? 0;
                        String status =
                            qData['status'] ?? 'waiting';

                        bool isCancelled =
                            status == 'cancelled';
                        bool isServed =
                            qNum <= current &&
                                !isCancelled;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isCancelled
                                ? Colors.grey.shade300
                                : (isServed
                                    ? Colors.green
                                        .shade400
                                    : Colors.indigo
                                        .shade300),
                            foregroundColor:
                                Colors.white,
                            child: Text("$qNum",
                                style: const TextStyle(
                                    fontWeight:
                                        FontWeight
                                            .bold)),
                          ),
                          title: Text(
                              isCancelled
                                  ? "คิวนี้ถูกยกเลิกแล้ว"
                                  : "คิวลำดับที่ $qNum",
                              style: TextStyle(
                                  color: isCancelled
                                      ? Colors.red
                                      : (isServed
                                          ? Colors.green
                                          : Colors
                                              .black),
                                  fontWeight:
                                      FontWeight.w500,
                                  decoration:
                                      isCancelled
                                          ? TextDecoration
                                              .lineThrough
                                          : null)),
                          subtitle: Text(
                              "สถานะ: ${isCancelled ? 'Cancelled' : status}"),
                          trailing: isCancelled
                              ? const Icon(Icons.close,
                                  color: Colors.red,
                                  size: 20)
                              : (isServed
                                  ? const Icon(
                                      Icons.check_circle,
                                      color:
                                          Colors.green,
                                      size: 20)
                                  : null),
                        );
                      },
                    );
                  },
                ),
              )
            ],
          );
        },
      ),
    );
  }

  Widget _statusItem(String title, String value) {
    return Column(
      children: [
        Text(title,
            style:
                const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.indigo)),
      ],
    );
  }
}