import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'booking_page.dart';
import 'my_ticket_page.dart';
import 'login_page.dart';
import 'staff_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TickFair Connect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF673AB7), 
          primary: const Color(0xFF673AB7)
        ),
        useMaterial3: true,
        textTheme: const TextTheme(
          headlineMedium: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF311B92)),
        ),
      ),
      // ส่วนที่ใช้ตรวจสอบสถานะการเข้าสู่ระบบ
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(), // ดักฟังการ Login/Logout
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          // ถ้ามีข้อมูล User (Login อยู่) ไปหน้ารายการกิจกรรม ถ้าไม่มี (Logout แล้ว) ไปหน้า Login
          return snapshot.hasData ? const EventListPage() : const LoginPage();
        },
      ),
    );
  }
}

// --- หน้าแสดงรายการกิจกรรม (EventListPage) ---
class EventListPage extends StatefulWidget {
  const EventListPage({super.key});
  @override
  State<EventListPage> createState() => _EventListPageState();
}

class _EventListPageState extends State<EventListPage> {
  List<String> bookedEvents = [];

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  void _loadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => bookedEvents = prefs.getStringList('booked_events') ?? []);
  }

  Future<void> _showLogoutDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("ออกจากระบบ"),
        content: const Text("คุณแน่ใจหรือไม่ว่าต้องการออกจากระบบ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ยกเลิก")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut(); // เมื่อสั่ง signOut ตรงนี้ StreamBuilder ด้านบนจะทำงานทันที
            },
            child: const Text("ยืนยัน", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF673AB7), Color(0xFF512DA8)]),
          ),
        ),
        title: const Text("TickFair Connect", 
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _showLogoutDialog, 
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('events').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              bool isBooked = bookedEvents.contains(doc.id);

              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 8))
                  ],
                ),
                child: InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => MyHomePage(eventId: doc.id, title: data['name']))).then((_) => _loadStatus()),
                  borderRadius: BorderRadius.circular(25),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    leading: isBooked 
                      ? const Icon(Icons.check_circle, color: Colors.green, size: 30)
                      : const Icon(Icons.event_note_rounded, color: Color(0xFF673AB7), size: 30),
                    title: Text(data['name'] ?? 'Event', 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF311B92))),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(data['location'] ?? 'Location', style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isBooked) 
                          const Text("จองแล้ว ", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                        IconButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => StaffPage(eventId: doc.id))),
                          icon: const Icon(Icons.admin_panel_settings, color: Colors.grey),
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
    );
  }
}

// --- หน้าจองคิว (MyHomePage) ---
class MyHomePage extends StatefulWidget {
  final String eventId;
  final String title;
  const MyHomePage({super.key, required this.eventId, required this.title});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? myQueueId;

  @override
  void initState() {
    super.initState();
    _loadMyQueue();
  }

  void _loadMyQueue() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => myQueueId = prefs.getString('user_id_${widget.eventId}'));
  }

  Future<void> _cancelQueue() async {
    final eventRef = FirebaseFirestore.instance.collection('events').doc(widget.eventId);
    final prefs = await SharedPreferences.getInstance();

    try {
      await eventRef.collection('queues').doc(myQueueId).delete();
      await prefs.remove('user_id_${widget.eventId}');
      List<String> booked = prefs.getStringList('booked_events') ?? [];
      booked.remove(widget.eventId);
      await prefs.setStringList('booked_events', booked);
      setState(() => myQueueId = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("ยกเลิกการจองเรียบร้อยแล้ว"), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("เกิดข้อผิดพลาด: $e")));
    }
  }

  Future<void> _takeQueue() async {
    final user = FirebaseAuth.instance.currentUser;
    final eventRef = FirebaseFirestore.instance.collection('events').doc(widget.eventId);
    String qId = "${user?.uid}_${widget.eventId}";

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        var snap = await tx.get(eventRef);
        int maxCapacity = snap.data()?.containsKey('maxCapacity') == true ? snap['maxCapacity'] : 100;
        int last = snap['lastQueueNumber'] ?? 0;
        if (last >= maxCapacity) throw Exception("ขออภัย ที่นั่งถูกจองเต็มจำนวนแล้ว");
        int next = last + 1;
        tx.update(eventRef, {'lastQueueNumber': next});
        tx.set(eventRef.collection('queues').doc(qId), {
          'queueNumber': next,
          'status': 'waiting',
          'userId': user?.uid,
          'timestamp': FieldValue.serverTimestamp(),
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id_${widget.eventId}', qId);
        List<String> booked = prefs.getStringList('booked_events') ?? [];
        if(!booked.contains(widget.eventId)) {
          booked.add(widget.eventId);
          await prefs.setStringList('booked_events', booked);
        }
      });
      _loadMyQueue();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll("Exception: ", ""))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold))),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('events').doc(widget.eventId).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData || !snap.data!.exists) return const Center(child: CircularProgressIndicator());
          var eventData = snap.data!.data() as Map<String, dynamic>;
          int current = eventData['currentServing'] ?? 0;
          int last = eventData['lastQueueNumber'] ?? 0;
          int max = eventData.containsKey('maxCapacity') ? eventData['maxCapacity'] : 100;
          int remaining = max - last;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildSeatCard("ที่นั่งทั้งหมด", "$max", const Color(0xFF2196F3)),
                    const SizedBox(width: 15),
                    _buildSeatCard("ที่นั่งว่างตอนนี้", "$remaining", remaining > 0 ? Colors.green : Colors.red),
                  ],
                ),
                const SizedBox(height: 50),
                const Text("ลำดับคิวที่กำลังเรียก", style: TextStyle(fontSize: 14, color: Colors.grey, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(colors: [Color(0xFF673AB7), Color(0xFF9575CD)]).createShader(bounds),
                  child: Text("$current", style: const TextStyle(fontSize: 120, fontWeight: FontWeight.w900, color: Colors.white, height: 1)),
                ),
                const SizedBox(height: 40),
                if (myQueueId == null)
                  _buildLargeButton(remaining > 0, _takeQueue, remaining > 0 ? "กดรับลำดับคิว" : "ขออภัย ที่นั่งเต็มแล้ว")
                else
                  _buildMyStatus(current),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLargeButton(bool enabled, VoidCallback onPressed, String text) {
    return Container(
      width: double.infinity, height: 65,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: enabled ? const LinearGradient(colors: [Color(0xFF673AB7), Color(0xFF5E35B1)]) : null,
        color: enabled ? null : Colors.grey.shade300,
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
        onPressed: enabled ? onPressed : null, 
        child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _buildSeatCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(25), border: Border.all(color: color.withOpacity(0.2), width: 1.5)),
        child: Column(children: [
          Text(title, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(value, style: TextStyle(fontSize: 30, color: color, fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }

  Widget _buildMyStatus(int current) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('events').doc(widget.eventId).collection('queues').doc(myQueueId).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) return const SizedBox();
        var data = snap.data!;
        int myNum = data['queueNumber'];
        String status = data['status'];
        bool isTurn = myNum <= current && status == 'waiting';
        int waitCount = myNum - current;

        return Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              width: double.infinity,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: isTurn ? const Color(0xFFFFF3E0) : Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: isTurn ? Colors.orange : Colors.deepPurple.shade100, width: 2),
              ),
              child: Column(
                children: [
                  if (isTurn) ...[
                    const Icon(Icons.notifications_active, color: Colors.orange, size: 50),
                    const Text("🎉 ถึงคิวคุณแล้ว!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.orange)),
                  ] else if (status == 'completed') ...[
                    const Icon(Icons.check_circle, color: Colors.green, size: 50),
                    const Text("จองสำเร็จ!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                  ] else ...[
                    const Text("คิวของคุณคือ", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    Text("#$myNum", style: const TextStyle(fontSize: 60, fontWeight: FontWeight.w900, color: Color(0xFF311B92))),
                    Text(waitCount > 0 ? "รออีก $waitCount คิว" : "กำลังเรียกคุณ...", style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
                  ],
                  const SizedBox(height: 25),
                  if (status == 'completed')
                    _buildActionBtn(Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (_) => MyTicketPage(userId: myQueueId!, eventId: widget.eventId))), "ดูตั๋ว E-Ticket", Icons.qr_code)
                  else if (isTurn)
                    _buildActionBtn(Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingPage(eventId: widget.eventId, userId: myQueueId!, queueNumber: myNum))), "จองที่นั่งเดี๋ยวนี้", Icons.touch_app)
                  else
                    const LinearProgressIndicator(),
                ],
              ),
            ),
            const SizedBox(height: 15),
            TextButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("ยืนยันการยกเลิก"),
                    content: const Text("คุณต้องการยกเลิกคิวนี้ใช่หรือไม่? ข้อมูลจะถูกลบออกถาวร"),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text("ไม่ยกเลิก")),
                      TextButton(onPressed: () { Navigator.pop(context); _cancelQueue(); }, 
                        child: const Text("ยืนยันยกเลิก", style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 18),
              label: const Text("ยกเลิกการจองคิวนี้", style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionBtn(Color color, VoidCallback onTap, String label, IconData icon) {
    return SizedBox(
      width: double.infinity, height: 55,
      child: ElevatedButton.icon(
        onPressed: onTap, icon: Icon(icon), label: Text(label),
        style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
      ),
    );
  }
}