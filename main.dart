import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';

// 🌤 Map weather conditions to emojis
String getWeatherIcon(String description) {
  description = description.toLowerCase();
  if (description.contains("clear")) return "☀️";
  if (description.contains("cloud")) return "☁️";
  if (description.contains("rain")) return "🌧️";
  if (description.contains("thunder")) return "⛈️";
  if (description.contains("snow")) return "❄️";
  if (description.contains("mist") ||
      description.contains("fog") ||
      description.contains("haze")) return "🌫️";
  return "🌍";
}

// 🌍 Weather Data Model
class WeatherData {
  final String city;
  final double temp;
  final double feelsLike;
  final int humidity;
  final double wind;
  final int cloudiness;
  final double rain;
  final String description;
  final List<dynamic> forecast;

  WeatherData({
    required this.city,
    required this.temp,
    required this.feelsLike,
    required this.humidity,
    required this.wind,
    required this.cloudiness,
    required this.rain,
    required this.description,
    required this.forecast,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final cityName = json['city']['name'];
    final current = json['list'][0];
    return WeatherData(
      city: cityName,
      temp: current['main']['temp'].toDouble(),
      feelsLike: current['main']['feels_like'].toDouble(),
      humidity: current['main']['humidity'],
      wind: current['wind']['speed'].toDouble(),
      cloudiness: current['clouds']['all'],
      rain: (current['rain'] != null && current['rain']['3h'] != null)
          ? current['rain']['3h'].toDouble()
          : 0.0,
      description: current['weather'][0]['description'],
      forecast: json['list'],
    );
  }
}

// 🔑 API Key (replace with your own)
const String apiKey = "fbdb127778cc8f225b39771eaf89a5e7";

// 🌐 Fetch Weather Function
Future<WeatherData> fetchWeather(String city) async {
  final url =
      "https://api.openweathermap.org/data/2.5/forecast?q=$city&appid=$apiKey&units=metric";
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    return WeatherData.fromJson(jsonDecode(response.body));
  } else {
    throw Exception("Failed to load weather data");
  }
}

// 🌟 Providers
final darkModeProvider = StateProvider<bool>((ref) => false);
final cityProvider = StateProvider<String>((ref) => "");
final forecastIndexProvider = StateProvider<double>((ref) => 0);

final weatherProvider =
    FutureProvider.family<WeatherData, String>((ref, city) async {
  if (city.isEmpty) throw Exception("Enter a city to get weather");
  return fetchWeather(city);
});

void main() {
  runApp(const ProviderScope(child: WeatherApp()));
}

class WeatherApp extends ConsumerWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(darkModeProvider);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const WeatherScreen()),
        GoRoute(
          path: '/details',
          builder: (context, state) {
            final WeatherData weather = state.extra as WeatherData;
            return DetailedForecastScreen(weather: weather);
          },
        ),
      ],
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.lightBlue.shade50,
        cardColor: Colors.lightBlue[100],
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        cardColor: const Color(0xFF7F1437),
      ),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }
}

class WeatherScreen extends ConsumerWidget {
  const WeatherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final city = ref.watch(cityProvider);
    final weatherAsync = ref.watch(weatherProvider(city));
    final isDark = ref.watch(darkModeProvider);
    final cardTextColor = isDark ? Colors.white : Colors.black;

    // 🔹 Controller for search TextField
    final TextEditingController cityController =
        TextEditingController(text: city);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "🌦 Weather App",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
            onPressed: () =>
                ref.read(darkModeProvider.notifier).state = !isDark,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // 🔍 Search Bar with working button
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: cityController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: "Enter city",
                    ),
                    onSubmitted: (value) =>
                        ref.read(cityProvider.notifier).state = value,
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    ref.read(cityProvider.notifier).state = cityController.text;
                  },
                  child: const Text("Search"),
                ),
              ],
            ),
            const SizedBox(height: 15),
            // Weather Data
            Expanded(
              child: weatherAsync.when(
                data: (weather) {
                  final forecastIndex =
                      ref.watch(forecastIndexProvider).toInt();
                  final selected = weather.forecast[forecastIndex];
                  final selectedTime = DateTime.parse(selected['dt_txt']);
                  final selectedTemp = selected['main']['temp'].toDouble();
                  final selectedDescription =
                      selected['weather'][0]['description'];

                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        // Current Weather Card
                        Card(
                          color: isDark
                              ? const Color(0xFF7F1437)
                              : Colors.lightBlue[100],
                          elevation: 4,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  weather.city.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: cardTextColor,
                                  ),
                                ),
                                Text(
                                  "${weather.temp}°C",
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepOrange,
                                  ),
                                ),
                                Text(
                                  "${getWeatherIcon(weather.description)} ${weather.description}",
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: cardTextColor,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 12,
                                  children: [
                                    Text(
                                      "💧 Humidity: ${weather.humidity}%",
                                      style: TextStyle(color: cardTextColor),
                                    ),
                                    Text(
                                      "💨 Wind: ${weather.wind} m/s",
                                      style: TextStyle(color: cardTextColor),
                                    ),
                                    Text(
                                      "☁️ Cloudiness: ${weather.cloudiness}%",
                                      style: TextStyle(color: cardTextColor),
                                    ),
                                    Text(
                                      "🌧️ Rain: ${weather.rain} mm",
                                      style: TextStyle(color: cardTextColor),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        // Forecast Slider & Cards
                        const Text(
                          "5-day forecast (3-hour steps):",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 180,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: weather.forecast.length,
                            itemBuilder: (context, index) {
                              final item = weather.forecast[index];
                              final dt = DateTime.parse(item['dt_txt']);
                              final temp = item['main']['temp'].toDouble();
                              final desc = item['weather'][0]['description'];
                              return GestureDetector(
                                onTap: () {
                                  GoRouter.of(context)
                                      .go('/details', extra: weather);
                                },
                                child: Card(
                                  color: index == forecastIndex
                                      ? Colors.orangeAccent
                                      : isDark
                                          ? const Color(0xFF7F1437)
                                          : Colors.lightBlueAccent,
                                  child: Container(
                                    width: 180,
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "${dt.day}/${dt.month} ${dt.hour}:00",
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          "${temp.toStringAsFixed(1)}°C",
                                          style: const TextStyle(fontSize: 22),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          "${getWeatherIcon(desc)} $desc",
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                        Slider(
                          value: ref.watch(forecastIndexProvider),
                          min: 0,
                          max: (weather.forecast.length - 1).toDouble(),
                          divisions: weather.forecast.length - 1,
                          label: "$forecastIndex",
                          onChanged: (value) => ref
                              .read(forecastIndexProvider.notifier)
                              .state = value,
                        ),
                        // Selected Forecast Card
                        Card(
                          color: isDark
                              ? const Color(0xFF7F1437)
                              : Colors.lightBlue[100],
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Selected: ${selectedTime.toLocal()}",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: cardTextColor),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "${getWeatherIcon(selectedDescription)} Weather: $selectedDescription",
                                        style: TextStyle(color: cardTextColor),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "💨 Wind: ${weather.wind} m/s",
                                        style: TextStyle(color: cardTextColor),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  height: 60,
                                  width: 1,
                                  color:
                                      isDark ? Colors.white54 : Colors.black54,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "🌡 Temp: ${selectedTemp}°C",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: cardTextColor),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "💧 Humidity: ${weather.humidity}%",
                                      style: TextStyle(color: cardTextColor),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "🤔 Feels: ${weather.feelsLike}°C",
                                      style: TextStyle(color: cardTextColor),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text("Error: $e")),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DetailedForecastScreen extends StatelessWidget {
  final WeatherData weather;
  const DetailedForecastScreen({super.key, required this.weather});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Detailed Forecast"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Card(
                color: Colors.blueGrey[100],
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        weather.city.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "${weather.temp}°C",
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),
                      Text(
                        "${getWeatherIcon(weather.description)} ${weather.description}",
                        style: const TextStyle(fontSize: 18),
                      ),
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
}
