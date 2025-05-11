import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
      routes: {
        '/register': (context) => const RegisterScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/home': (context) => const MainScreen(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          User? user = snapshot.data;
          if (user == null) {
            return const LoginScreen();
          }
          return const MainScreen();
        }
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  // 인증 상태 변경 스트림
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 로그인
  Future<String?> signInWithEmailAndPassword(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return '해당 이메일을 가진 사용자가 없습니다.';
      } else if (e.code == 'wrong-password') {
        return '잘못된 비밀번호입니다.';
      } else {
        return e.message;
      }
    } catch (e) {
      return e.toString();
    }
  }

  // 회원가입
  Future<String?> registerWithEmailAndPassword(String email, String password, String name) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      User? user = result.user;
      
      // Firestore에 사용자 데이터 저장
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'name': name,
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
          'photoUrl': '',
          'bio': '',
        });
      }
      
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        return '비밀번호가 너무 약합니다.';
      } else if (e.code == 'email-already-in-use') {
        return '이미 사용 중인 이메일입니다.';
      } else {
        return e.message;
      }
    } catch (e) {
      return e.toString();
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // 현재 사용자 확인
  User? get currentUser => _auth.currentUser;

  // 프로필 정보 가져오기
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
        return doc.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      _logger.e('프로필 가져오기 오류: $e');
      return null;
    }
  }

  // 프로필 업데이트
  Future<bool> updateProfile(String name, String bio) async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'name': name,
          'bio': bio,
        });
        return true;
      }
      return false;
    } catch (e) {
      _logger.e('프로필 업데이트 오류: $e');
      return false;
    }
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = '이메일과 비밀번호를 모두 입력해주세요.';
        _isLoading = false;
      });
      return;
    }

    final error = await _authService.signInWithEmailAndPassword(email, password);
    
    if (error != null) {
      setState(() {
        _errorMessage = error;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인 성공!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFB2FF00), width: 1),
                ),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      '로그인',
                      style: TextStyle(
                        color: Color(0xFFB2FF00),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(
                      color: Color(0xFFB2FF00),
                      thickness: 1,
                    ),
                    const SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '아이디(이메일)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFB2FF00), width: 1),
                          ),
                          child: TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'ENTER_EMAIL',
                              hintStyle: TextStyle(color: Colors.grey),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                              suffixIcon: Icon(
                                Icons.check_circle,
                                color: Color(0xFFB2FF00),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '비밀번호',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFB2FF00), width: 1),
                          ),
                          child: TextField(
                            controller: _passwordController,
                            obscureText: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'ENTER_PASSWORD',
                              hintStyle: TextStyle(color: Colors.grey),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                              suffixIcon: Icon(
                                Icons.check_circle,
                                color: Color(0xFFB2FF00),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _signIn,
                        icon: const Icon(Icons.lock, color: Colors.black),
                        label: const Text(
                          'LOGIN',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB2FF00),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '계정이 없으신가요?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/register');
                          },
                          child: const Text(
                            '지금 가입하기',
                            style: TextStyle(
                              color: Color(0xFFB2FF00),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
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

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // 입력 검증
    if (name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      setState(() {
        _errorMessage = '모든 필드를 입력해주세요.';
        _isLoading = false;
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _errorMessage = '비밀번호가 일치하지 않습니다.';
        _isLoading = false;
      });
      return;
    }

    if (!_agreedToTerms) {
      setState(() {
        _errorMessage = '이용약관에 동의해주세요.';
        _isLoading = false;
      });
      return;
    }

    // Firebase 회원가입
    final error = await _authService.registerWithEmailAndPassword(email, password, name);
    
    if (error != null) {
      setState(() {
        _errorMessage = error;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = false;
    });

    // 회원가입 성공 시 자동으로 프로필 화면으로 이동
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('회원가입 성공!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFB2FF00)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFB2FF00), width: 1),
                ),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      '회원가입',
                      style: TextStyle(
                        color: Color(0xFFB2FF00),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(
                      color: Color(0xFFB2FF00),
                      thickness: 1,
                    ),
                    const SizedBox(height: 20),
                    // 이메일 필드
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '아이디(이메일)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFB2FF00), width: 1),
                          ),
                          child: TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'ENTER_EMAIL',
                              hintStyle: TextStyle(color: Colors.grey),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                              suffixIcon: Icon(
                                Icons.check_circle,
                                color: Color(0xFFB2FF00),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // 비밀번호 필드
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '비밀번호',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFB2FF00), width: 1),
                          ),
                          child: TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'ENTER_PASSWORD',
                              hintStyle: TextStyle(color: Colors.grey),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                              suffixIcon: Icon(
                                Icons.check_circle,
                                color: Color(0xFFB2FF00),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // 비밀번호 확인 필드
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '비밀번호 확인',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFB2FF00), width: 1),
                          ),
                          child: TextField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'CONFIRM_PASSWORD',
                              hintStyle: TextStyle(color: Colors.grey),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                              suffixIcon: Icon(
                                Icons.check_circle,
                                color: Color(0xFFB2FF00),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // 에러 메시지 표시
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    const SizedBox(height: 25),
                    // 회원가입 버튼
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _register,
                        icon: const Icon(Icons.add, color: Colors.black),
                        label: const Text(
                          'REGISTER',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB2FF00),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '이미 계정이 있으신가요?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            '로그인하기',
                            style: TextStyle(
                              color: Color(0xFFB2FF00),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
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

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _profileData;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
    });
    
    _profileData = await _authService.getUserProfile();
    
    if (_profileData != null) {
      _nameController.text = _profileData!['name'] ?? '';
      _bioController.text = _profileData!['bio'] ?? '';
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _updateProfile() async {
    setState(() {
      _isSaving = true;
    });
    
    final name = _nameController.text.trim();
    final bio = _bioController.text.trim();
    
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이름을 입력해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isSaving = false;
      });
      return;
    }
    
    bool success = await _authService.updateProfile(name, bio);
    
    setState(() {
      _isSaving = false;
    });
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('프로필이 성공적으로 업데이트되었습니다.'),
          backgroundColor: Colors.green,
        ),
      );
      
      // 프로필 저장 성공 시 홈 화면으로 이동
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('프로필 업데이트에 실패했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _signOut() async {
    await _authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('프로필 설정', style: TextStyle(color: Colors.black)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black),
            onPressed: _signOut,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    // 프로필 이미지
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.blue.shade100,
                      child: const Icon(
                        Icons.person,
                        size: 60,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 30),
                    // 이름 입력 필드
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: '이름',
                        hintText: '사용자 이름을 입력하세요',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // 자기소개 입력 필드
                    TextField(
                      controller: _bioController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: '자기소개',
                        hintText: '자기소개를 입력하세요',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                      ),
                    ),
                    const SizedBox(height: 30),
                    // 저장 버튼
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _updateProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                '저장하기',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // 계정 정보
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(15.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '계정 정보',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            Text('이메일: ${_profileData?['email'] ?? ''}'),
                            const SizedBox(height: 5),
                            Text('가입일: ${_profileData?['createdAt'] != null ? _formatDate(_profileData!['createdAt']) : ''}'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    return '${dateTime.year}년 ${dateTime.month}월 ${dateTime.day}일';
  }
}

// MainScreen 클래스 추가 - 하단 네비게이션 바를 포함한 메인 화면
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  
  static const List<Widget> _screens = [
    HomeScreen(),
    ProfileScreen(),
  ];
  
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '프로필',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }
}

// HomeScreen 클래스 수정 - 운동 관리 홈 화면
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Logger _logger = Logger();
  
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<WorkoutLog>> _events = {};
  List<WorkoutLog> _selectedEvents = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadWorkoutLogs();
  }
  
  Future<void> _loadWorkoutLogs() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final querySnapshot = await _firestore
            .collection('workout_logs')
            .where('userId', isEqualTo: user.uid)
            .get();
        
        final events = <DateTime, List<WorkoutLog>>{};
        
        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          final timestamp = (data['date'] as Timestamp).toDate();
          final date = DateTime(timestamp.year, timestamp.month, timestamp.day);
          
          final log = WorkoutLog(
            id: doc.id,
            name: data['name'],
            date: timestamp,
            duration: data['duration'],
            calories: data['calories'],
            notes: data['notes'] ?? '',
          );
          
          if (events[date] != null) {
            events[date]!.add(log);
          } else {
            events[date] = [log];
          }
        }
        
        setState(() {
          _events = events;
          _selectedEvents = _getEventsForDay(_selectedDay!);
          _isLoading = false;
        });
      }
    } catch (e) {
      _logger.e('운동 기록 로드 오류: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  List<WorkoutLog> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              color: const Color(0xFFB2FF00),
            ),
            const SizedBox(width: 8),
            const Text(
              'Health Manager',
              style: TextStyle(
                color: Color(0xFFB2FF00),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFFB2FF00)),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_focusedDay.year} / ${DateFormat('MMM').format(_focusedDay).toUpperCase()}',
                  style: const TextStyle(
                    color: Color(0xFFB2FF00),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _focusedDay = DateTime(
                            _focusedDay.year,
                            _focusedDay.month - 1,
                            1,
                          );
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: const Color(0xFFB2FF00),
                        elevation: 0,
                        side: const BorderSide(color: Color(0xFFB2FF00)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        minimumSize: const Size(60, 30),
                      ),
                      child: const Text('PREV'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _focusedDay = DateTime(
                            _focusedDay.year,
                            _focusedDay.month + 1,
                            1,
                          );
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: const Color(0xFFB2FF00),
                        elevation: 0,
                        side: const BorderSide(color: Color(0xFFB2FF00)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        minimumSize: const Size(60, 30),
                      ),
                      child: const Text('NEXT'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          TableCalendar(
            firstDay: DateTime.utc(2022, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: CalendarFormat.month,
            availableCalendarFormats: const {CalendarFormat.month: 'Month'},
            eventLoader: _getEventsForDay,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
                _selectedEvents = _getEventsForDay(selectedDay);
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            headerVisible: false,
            daysOfWeekHeight: 40,
            rowHeight: 60,
            calendarStyle: const CalendarStyle(
              defaultTextStyle: TextStyle(color: Colors.white),
              weekendTextStyle: TextStyle(color: Colors.white),
              holidayTextStyle: TextStyle(color: Colors.white),
              outsideTextStyle: TextStyle(color: Colors.grey),
              defaultDecoration: BoxDecoration(
                border: Border.fromBorderSide(
                  BorderSide(color: Color(0xFFB2FF00), width: 0.5),
                ),
                color: Colors.black,
              ),
              weekendDecoration: BoxDecoration(
                border: Border.fromBorderSide(
                  BorderSide(color: Color(0xFFB2FF00), width: 0.5),
                ),
                color: Colors.black,
              ),
              outsideDecoration: BoxDecoration(
                border: Border.fromBorderSide(
                  BorderSide(color: Color(0xFFB2FF00), width: 0.5),
                ),
                color: Colors.black,
              ),
              selectedDecoration: BoxDecoration(
                border: Border.fromBorderSide(
                  BorderSide(color: Color(0xFFB2FF00), width: 2),
                ),
                color: Colors.black,
              ),
              todayDecoration: BoxDecoration(
                border: Border.fromBorderSide(
                  BorderSide(color: Color(0xFFB2FF00), width: 1),
                ),
                color: Color(0x22B2FF00),
              ),
              markerDecoration: BoxDecoration(
                color: Color(0xFFB2FF00),
                shape: BoxShape.circle,
              ),
              markerSize: 5,
              markersMaxCount: 3,
            ),
            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle: TextStyle(color: Color(0xFFB2FF00)),
              weekendStyle: TextStyle(color: Color(0xFFB2FF00)),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFB2FF00), width: 0.5),
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFB2FF00)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'RECENT_WORKOUT_LOGS',
                        style: TextStyle(
                          color: Color(0xFFB2FF00),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        color: const Color(0xFFB2FF00),
                        child: _isLoading
                            ? const Text(
                                'LOADING...',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              )
                            : const Text(
                                'ADD NEW',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: Text(
                              'LOADING_DATA...',
                              style: TextStyle(
                                color: Color(0xFFB2FF00),
                              ),
                            ),
                          )
                        : _selectedEvents.isEmpty
                            ? const Center(
                                child: Text(
                                  'NO_WORKOUT_LOGS',
                                  style: TextStyle(
                                    color: Color(0xFFB2FF00),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _selectedEvents.length,
                                itemBuilder: (context, index) {
                                  final event = _selectedEvents[index];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8.0),
                                    padding: const EdgeInsets.all(8.0),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: const Color(0xFFB2FF00)),
                                    ),
                                    child: ListTile(
                                      title: Text(
                                        event.name,
                                        style: const TextStyle(
                                          color: Color(0xFFB2FF00),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '시간: ${event.duration} 분',
                                            style: const TextStyle(color: Colors.white),
                                          ),
                                          Text(
                                            '칼로리: ${event.calories} kcal',
                                            style: const TextStyle(color: Colors.white),
                                          ),
                                          if (event.notes.isNotEmpty)
                                            Text(
                                              '메모: ${event.notes}',
                                              style: const TextStyle(color: Colors.white),
                                            ),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Color(0xFFB2FF00)),
                                            onPressed: () => _showWorkoutLogDialog(event),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Color(0xFFB2FF00)),
                                            onPressed: () => _deleteWorkoutLog(event),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFB2FF00),
        onPressed: () => _showWorkoutLogDialog(null),
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Future<void> _showWorkoutLogDialog(WorkoutLog? log) async {
    final nameController = TextEditingController(text: log?.name ?? '');
    final durationController = TextEditingController(text: log?.duration.toString() ?? '');
    final caloriesController = TextEditingController(text: log?.calories.toString() ?? '');
    final notesController = TextEditingController(text: log?.notes ?? '');
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(
          log == null ? '운동 기록 추가' : '운동 기록 수정',
          style: const TextStyle(color: Color(0xFFB2FF00)),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: '운동 이름',
                  labelStyle: TextStyle(color: Colors.white),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFB2FF00)),
                  ),
                ),
              ),
              TextField(
                controller: durationController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '운동 시간 (분)',
                  labelStyle: TextStyle(color: Colors.white),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFB2FF00)),
                  ),
                ),
              ),
              TextField(
                controller: caloriesController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '소모 칼로리 (kcal)',
                  labelStyle: TextStyle(color: Colors.white),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFB2FF00)),
                  ),
                ),
              ),
              TextField(
                controller: notesController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: '메모',
                  labelStyle: TextStyle(color: Colors.white),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFB2FF00)),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('취소', style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('저장', style: TextStyle(color: Color(0xFFB2FF00))),
            onPressed: () {
              final name = nameController.text.trim();
              final durationText = durationController.text.trim();
              final caloriesText = caloriesController.text.trim();
              final notes = notesController.text.trim();

              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('운동 이름을 입력하세요')),
                );
                return;
              }

              final duration = int.tryParse(durationText) ?? 0;
              final calories = int.tryParse(caloriesText) ?? 0;

              if (log == null) {
                _addWorkoutLog(name, duration, calories, notes);
              } else {
                _updateWorkoutLog(log.id, name, duration, calories, notes);
              }

              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _addWorkoutLog(
    String name,
    int duration,
    int calories,
    String notes,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final docRef = await _firestore
            .collection('workout_logs')
            .add({
          'userId': user.uid,
          'name': name,
          'date': Timestamp.fromDate(_selectedDay!),
          'duration': duration,
          'calories': calories,
          'notes': notes,
          'createdAt': FieldValue.serverTimestamp(),
        });

        final log = WorkoutLog(
          id: docRef.id,
          name: name,
          date: _selectedDay!,
          duration: duration,
          calories: calories,
          notes: notes,
        );

        setState(() {
          final day = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
          if (_events[day] != null) {
            _events[day]!.add(log);
          } else {
            _events[day] = [log];
          }
          _selectedEvents = _getEventsForDay(_selectedDay!);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('운동 기록이 추가되었습니다')),
        );
      }
    } catch (e) {
      _logger.e('운동 기록 추가 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('운동 기록 추가에 실패했습니다')),
      );
    }
  }

  Future<void> _updateWorkoutLog(
    String id,
    String name,
    int duration,
    int calories,
    String notes,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore
            .collection('workout_logs')
            .doc(id)
            .update({
          'name': name,
          'duration': duration,
          'calories': calories,
          'notes': notes,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        setState(() {
          final day = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
          final index = _events[day]?.indexWhere((log) => log.id == id) ?? -1;
          
          if (index != -1) {
            _events[day]![index] = WorkoutLog(
              id: id,
              name: name,
              date: _selectedDay!,
              duration: duration,
              calories: calories,
              notes: notes,
            );
            _selectedEvents = _getEventsForDay(_selectedDay!);
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('운동 기록이 업데이트되었습니다')),
        );
      }
    } catch (e) {
      _logger.e('운동 기록 업데이트 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('운동 기록 업데이트에 실패했습니다')),
      );
    }
  }

  Future<void> _deleteWorkoutLog(WorkoutLog log) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore
            .collection('workout_logs')
            .doc(log.id)
            .delete();

        setState(() {
          final day = DateTime(log.date.year, log.date.month, log.date.day);
          _events[day]?.removeWhere((item) => item.id == log.id);
          
          if (_events[day]?.isEmpty ?? false) {
            _events.remove(day);
          }
          
          _selectedEvents = _getEventsForDay(_selectedDay!);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('운동 기록이 삭제되었습니다')),
        );
      }
    } catch (e) {
      _logger.e('운동 기록 삭제 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('운동 기록 삭제에 실패했습니다')),
      );
    }
  }
}

class WorkoutLog {
  final String id;
  final String name;
  final DateTime date;
  final int duration;
  final int calories;
  final String notes;

  WorkoutLog({
    required this.id,
    required this.name,
    required this.date,
    required this.duration,
    required this.calories,
    required this.notes,
  });
}

