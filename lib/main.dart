import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

// --- GLOBAL STATES ---
final ValueNotifier<String> appLanguage = ValueNotifier<String>('English');
final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier<ThemeMode>(ThemeMode.light);

// Simple Translation Dictionary
String tr(String text) {
  if (appLanguage.value == 'English') return text;
  Map<String, String> marathi = {
    "Home": "मुख्यपृष्ठ", "Scan": "स्कॅन", "Garden": "माझी बाग", "Community": "समुदाय", "Profile": "प्रोफाइल",
    "Plant Doctor": "वनस्पती डॉक्टर", "Scan Plant": "वनस्पती स्कॅन करा", "Add Crop": "पीक जोडा",
    "Dark Mode": "डार्क मोड", "App Language": "अॅप भाषा", "Log Out": "लॉग आउट करा", "Market Prices": "बाजार भाव",
    "Agriculture News": "शेती बातम्या", "Diagnosis & Remedy": "निदान आणि उपाय"
  };
  Map<String, String> hindi = {
    "Home": "होम", "Scan": "स्कैन", "Garden": "मेरा बगीचा", "Community": "समुदाय", "Profile": "प्रोफ़ाइल",
    "Plant Doctor": "पौधा डॉक्टर", "Scan Plant": "पौधा स्कैन करें", "Add Crop": "फसल जोड़ें",
    "Dark Mode": "डार्क मोड", "App Language": "ऐप की भाषा", "Log Out": "लॉग आउट करें", "Market Prices": "मंडी भाव",
    "Agriculture News": "कृषि समाचार", "Diagnosis & Remedy": "निदान और उपाय"
  };
  if (appLanguage.value == 'मराठी') return marathi[text] ?? text;
  if (appLanguage.value == 'हिंदी') return hindi[text] ?? text;
  return text;
}

final Map<String, String> diseaseSolutions = {
  // --- TOMATO ---
  "tomato healthy": "✅ Your tomato plant is healthy and vibrant!\n• Keep watering regularly.",
  "tomato earlyblight": "• Prune bottom leaves to improve airflow.\n• Apply copper-based fungicide sprays.",
  "tomato lateblight": "⚠️ DANGER: Severe disease!\n• Remove and destroy affected parts immediately.",

  // --- POTATO ---
  "potato healthy": "✅ Your potato plant is looking great!\n• Maintain proper soil moisture.",
  "potato earlyblight": "• Rotate crops next season.\n• Use chlorothalonil fungicide.",
  "potato lateblight": "⚠️ DANGER: Late blight spreads fast!\n• Apply systemic fungicides immediately.",

  // --- CORN ---
  "corn healthy": "✅ Your corn is growing perfectly!\n• Ensure adequate nitrogen levels.",
  "corn cercospora": "• (Gray Leaf Spot) Use foliar fungicides.\n• Consider resistant hybrids next season.",

  // --- BACKGROUND CLASS ---
  "unrecognized object": "Hmm, this doesn't look like a plant I know!\n• Please scan a tomato, potato, or corn leaf."
};

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Initialize Supabase ---
  // ⚠️ PASTE YOUR URL AND ANON KEY HERE!
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL_HERE',
    anonKey: 'YOUR_SUPABASE_ANON_KEY_HERE',
  );

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  runApp(const KrishiAIApp());
}

final supabase = Supabase.instance.client;

class KrishiAIApp extends StatelessWidget {
  const KrishiAIApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
        valueListenable: appThemeMode,
        builder: (context, currentThemeMode, _) {
          return ValueListenableBuilder<String>(
              valueListenable: appLanguage,
              builder: (context, lang, child) {
                return MaterialApp(
                  debugShowCheckedModeBanner: false,
                  title: 'KrishiAI',
                  themeMode: currentThemeMode,
                  theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true, scaffoldBackgroundColor: const Color(0xFFF5F9F5)),
                  darkTheme: ThemeData(primarySwatch: Colors.green, useMaterial3: true, scaffoldBackgroundColor: const Color(0xFF121212), brightness: Brightness.dark),
                  home: const AuthWrapper(),
                );
              }
          );
        }
    );
  }
}

// --- SECURITY GUARD ---
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}
class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final session = snapshot.data?.session;
        if (session != null) return const MainNavigationScreen();
        return const AuthScreen();
      },
    );
  }
}

// --- LOGIN & SIGNUP SCREEN ---
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}
class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool isLoading = false;

  Future<void> _submit() async {
    setState(() => isLoading = true);
    try {
      if (isLogin) {
        await supabase.auth.signInWithPassword(email: _emailController.text.trim(), password: _passwordController.text.trim());
      } else {
        await supabase.auth.signUp(email: _emailController.text.trim(), password: _passwordController.text.trim());
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Account created! Please log in."), backgroundColor: Colors.green));
        setState(() => isLogin = true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.eco, size: 80, color: Colors.green),
                const SizedBox(height: 20),
                Text(isLogin ? "Welcome to KrishiAI" : "Join KrishiAI", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 40),
                TextField(controller: _emailController, decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)), keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 20),
                TextField(controller: _passwordController, decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)), obscureText: true),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    onPressed: isLoading ? null : _submit,
                    child: isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(isLogin ? "Login" : "Sign Up", style: const TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(height: 15),
                TextButton(onPressed: () => setState(() => isLogin = !isLogin), child: Text(isLogin ? "New farmer? Create an account" : "Already have an account? Login", style: const TextStyle(color: Colors.green)))
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- MAIN NAVIGATION ---
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}
class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  final List<Widget> _screens = [const HomeScreen(), const ScannerScreen(), const MyGardenScreen(), const CommunityScreen(), const ProfileScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: tr('Home')),
          NavigationDestination(icon: const Icon(Icons.qr_code_scanner), label: tr('Scan')),
          NavigationDestination(icon: const Icon(Icons.eco_outlined), selectedIcon: const Icon(Icons.eco), label: tr('Garden')),
          NavigationDestination(icon: const Icon(Icons.people_outline), selectedIcon: const Icon(Icons.people), label: tr('Community')),
          NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: tr('Profile')),
        ],
      ),
    );
  }
}

// --- 1. HOME SCREEN (LIVE WEATHER & PHOTOS) ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _location = "Fetching location...";
  String _temperature = "--";
  bool _isLoadingWeather = true;

  @override
  void initState() {
    super.initState();
    _getLiveWeatherAndLocation();
  }

  Future<void> _getLiveWeatherAndLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() { _location = "Location Denied"; _isLoadingWeather = false; });
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        setState(() => _location = "${placemarks[0].locality}, ${placemarks[0].administrativeArea}");
      }

      final url = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=${position.latitude}&longitude=${position.longitude}&current_weather=true');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _temperature = "${data['current_weather']['temperature'].round()}°C";
          _isLoadingWeather = false;
        });
      }
    } catch (e) {
      setState(() { _location = "Location unavailable"; _isLoadingWeather = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userEmailName = supabase.auth.currentUser?.email?.split('@')[0] ?? "Farmer";
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ChatbotScreen())),
            backgroundColor: Colors.green.shade700,
            icon: const Icon(Icons.chat, color: Colors.white),
            label: const Text("Ask AI", style: TextStyle(color: Colors.white))
        ),
        body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Hello, $userEmailName! 👋", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.green),
                const SizedBox(width: 5),
                Text(_location, style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey)),
              ],
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)]), borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("Live Weather", style: TextStyle(color: Colors.white70)),
                    _isLoadingWeather
                        ? const Padding(padding: EdgeInsets.only(top: 8.0), child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                        : Text(_temperature, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                  ]),
                  const Spacer(),
                  const Icon(Icons.wb_sunny, color: Colors.yellow, size: 40),
                ],
              ),
            ),

            const SizedBox(height: 25),
            Text("📢 ${tr('Market Prices')}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                    children: [
                      _marketCard(context, "Tomato", "₹1,200/qt", "https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=500&q=80"),
                      _marketCard(context, "Potato", "₹900/qt", "https://images.unsplash.com/photo-1518977676601-b53f82aba655?w=500&q=80"),
                      _marketCard(context, "Onion", "₹1,500/qt", "https://images.unsplash.com/photo-1618512496248-a07fe83aa8cb?w=500&q=80"),
                      _marketCard(context, "Wheat", "₹2,100/qt", "https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b?w=500&q=80"),
                    ]
                )
            ),

            const SizedBox(height: 25),
            Text("📰 ${tr('Agriculture News')}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _newsCard(context, "Govt Announces New Subsidy", "Farmers to get 50% off on solar pumps...", "2h ago"),
            _newsCard(context, "Monsoon Update 2026", "Heavy rains expected in your region...", "5h ago"),
          ],
        ),
      ),
        ));
  }

  Widget _marketCard(BuildContext context, String name, String price, String imageUrl) {
    return Container(
        margin: const EdgeInsets.only(right: 15), width: 130,
        decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]
        ),
        child: Column(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: Image.network(imageUrl, height: 80, width: double.infinity, fit: BoxFit.cover),
              ),
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(price, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            ]
        )
    );
  }

  Widget _newsCard(BuildContext context, String title, String subtitle, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15), padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(15)),
      child: Row(children: [
        Container(height: 60, width: 60, decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.article, color: Colors.green)),
        const SizedBox(width: 15),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)),
          Text(time, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ]))
      ]),
    );
  }
}

// --- 2. SCANNER SCREEN ---
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}
class _ScannerScreenState extends State<ScannerScreen> {
  File? _selectedImage;
  String _label = "Scan a plant";
  String _solution = "";
  double _confidence = 0.0;
  bool _isAnalyzing = false;
  Interpreter? _interpreter;
  List<String> _labels = [];

  @override
  void initState() { super.initState(); _loadModel(); }
  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/model.tflite');
      final labelData = await rootBundle.loadString('assets/labels.txt');
      _labels = labelData.split('\n').where((s) => s.isNotEmpty).toList();
    } catch (e) { print("Error: $e"); }
  }

  Future<void> _pickImage(ImageSource source) async {
    final image = await ImagePicker().pickImage(source: source);
    if (image != null) {
      setState(() { _selectedImage = File(image.path); _isAnalyzing = true; _label = "Analyzing..."; _solution = "";});
      await Future.delayed(const Duration(milliseconds: 200));
      _runInference(File(image.path));
    }
  }

  Future<void> _runInference(File imageFile) async {
    if (_interpreter == null) return;
    final originalImage = img.decodeImage(imageFile.readAsBytesSync());
    final resizedImage = img.copyResizeCropSquare(originalImage!, size: 224);

    var input = Float32List(1 * 224 * 224 * 3);
    var buffer = Float32List.view(input.buffer);
    int pixelIndex = 0;
    for (var y = 0; y < 224; y++) {
      for (var x = 0; x < 224; x++) {
        var pixel = resizedImage.getPixel(x, y);
        buffer[pixelIndex++] = (pixel.r - 127.5) / 127.5;
        buffer[pixelIndex++] = (pixel.g - 127.5) / 127.5;
        buffer[pixelIndex++] = (pixel.b - 127.5) / 127.5;
      }
    }

    var output = List.filled(1 * _labels.length, 0.0).reshape([1, _labels.length]);
    _interpreter!.run(input.reshape([1, 224, 224, 3]), output);

    List<double> result = List<double>.from(output[0]);
    double maxScore = -100.0; int maxIndex = 0;
    for (int i = 0; i < result.length; i++) {
      if (result[i] > maxScore) { maxScore = result[i]; maxIndex = i; }
    }

    String cleanLabel = _labels[maxIndex].replaceAll(RegExp(r'[0-9]'), '').replaceAll('_', ' ').trim();
    String lookupKey = cleanLabel.toLowerCase();
    String remedy = diseaseSolutions[lookupKey] ?? "No specific remedy found. Please consult an expert.";

    setState(() {
      _isAnalyzing = false;
      _confidence = (maxScore > 1.0) ? maxScore / 2.55 : maxScore * 100;
      if (_confidence > 100) _confidence = 99.9;

      // Always show the AI's best guess!
      _label = cleanLabel;
      _solution = remedy;

      // But add a little warning if it is struggling to see it clearly
      if (_confidence < 60.0) {
        _solution = "⚠️ Note: The AI is not highly confident about this image. \n\n$_solution";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min, // Keeps it perfectly centered
          children: [
            Image.asset('assets/logo.png', height: 35), // Your new logo!
            const SizedBox(width: 10), // A little space between logo and text
            Text(tr("Plant Doctor")), // Keeps your original text
          ],
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(height: 300, width: double.infinity, decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20), image: _selectedImage != null ? DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover) : null), child: _selectedImage == null ? const Center(child: Icon(Icons.add_a_photo, size: 50, color: Colors.grey)) : null),
            const SizedBox(height: 20),
            if (_isAnalyzing) const CircularProgressIndicator(color: Colors.green)
            else if (_label != "Scan a plant" && _selectedImage != null)
              Column(children: [
                Text(_label, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text("Confidence: ${_confidence.toStringAsFixed(1)}%", style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 20),
                Container(padding: const EdgeInsets.all(20), width: double.infinity, decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.green.shade700)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(tr("Diagnosis & Remedy"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)), const Divider(), Text(_solution, style: const TextStyle(fontSize: 16, height: 1.5))]))
              ]),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: SizedBox(
                      height: 55,
                      child: ElevatedButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text("Camera", style: TextStyle(fontSize: 18)),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white)
                      )
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: SizedBox(
                      height: 55,
                      child: ElevatedButton.icon(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library),
                          label: const Text("Gallery", style: TextStyle(fontSize: 18)),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white)
                      )
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- 3. MY GARDEN ---
class MyGardenScreen extends StatefulWidget {
  const MyGardenScreen({super.key});
  @override
  State<MyGardenScreen> createState() => _MyGardenScreenState();
}
class _MyGardenScreenState extends State<MyGardenScreen> {
  final TextEditingController _cropController = TextEditingController();

  void _showAddDialog() {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: Text(tr("Add Crop")),
      content: TextField(controller: _cropController, decoration: const InputDecoration(hintText: "Crop Name", border: OutlineInputBorder())),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: () async {
            if (_cropController.text.isNotEmpty) {
              final user = supabase.auth.currentUser;
              if (user != null) {
                await supabase.from('crops').insert({
                  'name': _cropController.text,
                  'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                  'owner_id': user.id,
                });
              }
              _cropController.clear();
              if(context.mounted) Navigator.pop(context);
            }
          },
          child: const Text("Add"),
        )
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr("My Garden")), centerTitle: true),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase.from('crops').stream(primaryKey: ['id']).eq('owner_id', supabase.auth.currentUser!.id).order('created_at'),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var crops = snapshot.data!;
          if (crops.isEmpty) return const Center(child: Text("Your garden is empty. Add a crop!"));

          return ListView.builder(
            padding: const EdgeInsets.all(20), itemCount: crops.length,
            itemBuilder: (context, index) {
              var cropData = crops[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 15),
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.grass, color: Colors.white)),
                  title: Text(cropData["name"] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Planted: ${cropData["date"]}"),
                  trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => supabase.from('crops').delete().eq('id', cropData["id"])
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: _showAddDialog, backgroundColor: Colors.green, child: const Icon(Icons.add, color: Colors.white)),
    );
  }
}

// --- 4. COMMUNITY SCREEN ---
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});
  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}
class _CommunityScreenState extends State<CommunityScreen> {
  final TextEditingController _postController = TextEditingController();

  void _showPostDialog() {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: Text(tr("Community")),
      content: TextField(controller: _postController, maxLines: 3, decoration: const InputDecoration(hintText: "Write a post...", border: OutlineInputBorder())),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: () async {
            if (_postController.text.isNotEmpty) {
              await supabase.from('posts').insert({
                'user_name': supabase.auth.currentUser?.email?.split('@')[0] ?? "Farmer",
                'post': _postController.text,
              });
              _postController.clear();
              if(context.mounted) Navigator.pop(context);
            }
          },
          child: const Text("Post"),
        )
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr("Community")), centerTitle: true),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase.from('posts').stream(primaryKey: ['id']).order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var posts = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(20), itemCount: posts.length,
            itemBuilder: (context, index) {
              var postData = posts[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 15),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(postData["user_name"] ?? "Farmer", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    const SizedBox(height: 5),
                    Text(postData["post"] ?? "", style: const TextStyle(fontSize: 16)),
                  ]),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: _showPostDialog, backgroundColor: Colors.green, child: const Icon(Icons.edit, color: Colors.white)),
    );
  }
}

// --- 5. PROFILE SCREEN ---
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    return Scaffold(
      appBar: AppBar(title: Text(tr("Profile")), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const CircleAvatar(radius: 50, backgroundColor: Colors.green, child: Icon(Icons.person, size: 50, color: Colors.white)),
            const SizedBox(height: 10),
            Text(user?.email ?? "Farmer", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            Card(child: SwitchListTile(title: Text(tr("Dark Mode")), secondary: const Icon(Icons.dark_mode, color: Colors.green), value: appThemeMode.value == ThemeMode.dark, onChanged: (isDark) => appThemeMode.value = isDark ? ThemeMode.dark : ThemeMode.light)),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: const Icon(Icons.language, color: Colors.green),
                title: Text(tr("App Language")),
                trailing: ValueListenableBuilder<String>(
                    valueListenable: appLanguage,
                    builder: (context, value, child) {
                      return DropdownButton<String>(
                        value: value, underline: const SizedBox(),
                        items: const [ DropdownMenuItem(value: 'English', child: Text("English")), DropdownMenuItem(value: 'मराठी', child: Text("मराठी")), DropdownMenuItem(value: 'हिंदी', child: Text("हिंदी")) ],
                        onChanged: (newValue) { if (newValue != null) appLanguage.value = newValue; },
                      );
                    }
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade100, foregroundColor: Colors.red.shade900),
                  onPressed: () async => await supabase.auth.signOut(),
                  icon: const Icon(Icons.logout), label: Text(tr("Log Out"))
              ),
            )
          ],
        ),
      ),
    );
  }
}
// --- 6. KRISHI AI CHATBOT (MVP VERSION) ---
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});
  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _msgController = TextEditingController();
  final List<Map<String, String>> _messages = [
    {"role": "bot", "text": "Hello! I am KrishiAI. Ask me about crop diseases, fertilizers, or weather!"}
  ];

  void _sendMessage() async {
    if (_msgController.text.trim().isEmpty) return;
    String userText = _msgController.text.trim();

    setState(() {
      _messages.insert(0, {"role": "user", "text": userText});
      _msgController.clear();
      _messages.insert(0, {"role": "bot", "text": "Thinking..."});
    });

    // 1. PASTE YOUR REAL API KEY IN THE QUOTES BELOW
    String apiKey = "YOUR_API_KEY_HERE".trim();

    try {
      // 2. UPDATED TO GEMINI 2.5 FLASH!
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": "You are KrishiAI, an expert agricultural assistant app for Indian farmers. Keep your answer short, friendly, and strictly related to farming, crops, weather, or agriculture. Answer this: $userText"}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String botReply = data['candidates'][0]['content']['parts'][0]['text'];

        setState(() {
          _messages[0] = {"role": "bot", "text": botReply.replaceAll('*', '').trim()};
        });
      } else {
        setState(() {
          _messages[0] = {"role": "bot", "text": "Oops! Server Error (Status: ${response.statusCode}). Check your API key!"};
        });
      }
    } catch (e) {
      setState(() {
        _messages[0] = {"role": "bot", "text": "Network error! Please check your internet connection."};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("KrishiAI Assistant"), backgroundColor: Colors.green, foregroundColor: Colors.white),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(15),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                bool isUser = _messages[index]["role"] == "user";
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(15),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                        color: isUser ? Colors.green.shade600 : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20).copyWith(
                          bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(20),
                          bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(0),
                        ),
                        border: isUser ? null : Border.all(color: Colors.green.shade200)
                    ),
                    child: Text(_messages[index]["text"]!, style: TextStyle(color: isUser ? Colors.white : null, fontSize: 16)),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            color: Theme.of(context).cardColor,
            child: Row(
              children: [
                Expanded(child: TextField(controller: _msgController, decoration: InputDecoration(hintText: "Ask a farming question...", border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)), contentPadding: const EdgeInsets.symmetric(horizontal: 20)))),
                const SizedBox(width: 10),
                CircleAvatar(backgroundColor: Colors.green, radius: 25, child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: _sendMessage))
              ],
            ),
          )
        ],
      ),
    );
  }
}