import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NewsService {
  // Replace this with your actual GNews API key once you have it
  static const String _apiKey = 'e739ac686a95f6039c1efe04b1a2e4e5'; 
  static const String _apiUrl = 
      'https://gnews.io/api/v4/search?q=agriculture OR farming OR crops&lang=en&apikey=$_apiKey';
  static const String _cacheKey = 'cached_news';

  Future<List<dynamic>> fetchAgricultureNews() async {
    // 1. Check network connectivity
    var connectivityResult = await (Connectivity().checkConnectivity());
    bool isConnected = !connectivityResult.contains(ConnectivityResult.none);
    SharedPreferences prefs = await SharedPreferences.getInstance();

    if (isConnected) {
      try {
        // 2. Fetch live data if online
        final response = await http.get(Uri.parse(_apiUrl));

        if (response.statusCode == 200) {
          final decodedData = json.decode(response.body);
          final articles = decodedData['articles'] as List<dynamic>;

          // 3. Cache the successful response for offline use
          await prefs.setString(_cacheKey, json.encode(articles));
          
          return articles;
        }
      } catch (e) {
        print("Error fetching live news: $e");
        // Fall back to cache if the HTTP request fails despite having network
      }
    }

    // 4. Load from cache if offline (or if the live request failed)
    String? cachedData = prefs.getString(_cacheKey);
    if (cachedData != null) {
      return json.decode(cachedData);
    }

    // Return empty list if no internet and no cache exists yet
    return []; 
  }
}