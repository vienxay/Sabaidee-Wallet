import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/payment_service.dart';
import 'package:intl/date_symbol_data_local.dart';
void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  // ✅ ເລີ່ມຕົ້ນ locale data ສຳລັບພາສາລາວ
  await initializeDateFormatting('lo');

  runApp(const SabaideeWallet());
}

class SabaideeWallet extends StatelessWidget {
  const SabaideeWallet({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => PaymentService()), // ⭐ ເພີ່ມ
      ],
      child: MaterialApp(
        title: 'Sabaidee Wallet',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: const Color(0xFFFF9800),
          scaffoldBackgroundColor: Colors.white,
          textTheme: GoogleFonts.notoSansLaoTextTheme(),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFFF9800),
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    
    await Future.delayed(const Duration(seconds: 2));

    final hasSession = await authService.checkSession();

    if (!mounted) return;

    if (hasSession) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',  // ປ່ຽນເປັນຊື່ໄຟລ໌ຂອງເຈົ້າ
              width: 300,
              height: 300,
            ),
            // const SizedBox(height: 24),
            // // const Text(
            // //   '',
            // //   style: TextStyle(
            // //     fontSize: 24,
            // //     fontWeight: FontWeight.bold,
            // //   ),
            // // ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(
              color: Color(0xFFFF9800),
            ),
          ],
        ),
      ),
    );
  }
}