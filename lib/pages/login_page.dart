import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart'; 

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool isLogin = true; 
  bool _isAccepted = false;
  bool _isLoading = false;

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;
    if (!isLogin && !_isAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("กรุณายอมรับข้อกำหนดการใช้งานก่อนลงทะเบียน"), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }

      final prefs = await SharedPreferences.getInstance();
      String displayName = _emailController.text.split('@')[0];
      await prefs.setString('username', displayName);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const EventListPage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = "เกิดข้อผิดพลาด";
      if (e.code == 'user-not-found') message = "ไม่พบผู้ใช้นี้ในระบบ";
      else if (e.code == 'wrong-password') message = "รหัสผ่านไม่ถูกต้อง";
      else if (e.code == 'email-already-in-use') message = "อีเมลนี้ถูกใช้งานแล้ว";
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showTerms() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: const Row(
          children: [
            Icon(Icons.description_outlined, color: Colors.deepPurple),
            SizedBox(width: 10),
            Text("ข้อกำหนดการใช้งาน", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            "1. 1 บัญชีผู้ใช้งานสามารถจองได้ 1 สิทธิ์ต่อ 1 กิจกรรมเท่านั้น\n\n"
            "2. ระบบจะจัดลำดับคิวตามลำดับเวลาที่กดรับคิวจริง\n\n"
            "3. หากถึงลำดับคิวแล้วไม่ดำเนินการภายในเวลาที่กำหนด ระบบจะถือว่าสละสิทธิ์",
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ตกลง", style: TextStyle(fontWeight: FontWeight.bold)))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF673AB7), Color(0xFF311B92)], // สีม่วงเข้มไล่ระดับ
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // --- Logo Section ---
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.confirmation_num_rounded, size: 80, color: Colors.white),
                    ),
                    const SizedBox(height: 15),
                    const Text("TickFair Connect", 
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.2)),
                    const Text("Smart Queue Management", style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 40),

                    // --- Input Card ---
                    Container(
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(35),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 25, offset: const Offset(0, 10))
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isLogin ? "Welcome Back" : "Create Account", 
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF311B92))),
                          const SizedBox(height: 25),
                          
                          // Email Field
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: "อีเมล",
                              prefixIcon: const Icon(Icons.email_outlined),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                            ),
                            validator: (val) => (val == null || !val.contains('@')) ? "กรุณากรอกอีเมลให้ถูกต้อง" : null,
                          ),
                          const SizedBox(height: 15),

                          // Password Field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: "รหัสผ่าน",
                              prefixIcon: const Icon(Icons.lock_outline),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                            ),
                            validator: (val) => (val == null || val.length < 6) ? "รหัสผ่านต้องมี 6 ตัวขึ้นไป" : null,
                          ),

                          // Terms Checkbox (Only Register)
                          if (!isLogin) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                SizedBox(
                                  height: 24, width: 24,
                                  child: Checkbox(
                                    value: _isAccepted, 
                                    onChanged: (v) => setState(() => _isAccepted = v!),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text("ฉันยอมรับ", style: TextStyle(fontSize: 13)),
                                TextButton(
                                  onPressed: _showTerms, 
                                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                                  child: const Text("ข้อกำหนดการใช้งาน", 
                                    style: TextStyle(fontSize: 13, decoration: TextDecoration.underline, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 25),

                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleAuth,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF673AB7),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                elevation: 5,
                              ),
                              child: _isLoading 
                                ? const CircularProgressIndicator(color: Colors.white) 
                                : Text(isLogin ? "เข้าสู่ระบบ" : "ลงทะเบียนและยอมรับเงื่อนไข", 
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Toggle Button
                    TextButton(
                      onPressed: () => setState(() {
                        isLogin = !isLogin;
                        _formKey.currentState!.reset();
                      }),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                          children: [
                            TextSpan(text: isLogin ? "ยังไม่มีบัญชี? " : "มีบัญชีอยู่แล้ว? "),
                            TextSpan(
                              text: isLogin ? "ลงทะเบียนที่นี่" : "เข้าสู่ระบบที่นี่",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}