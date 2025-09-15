import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:json_annotation/json_annotation.dart';
import 'package:video_player/video_player.dart';

part 'main.g.dart';

// 🌤 Weather icons - UPDATED TO USE WEATHER ID
String getWeatherIcon(int weatherId) {
  if (weatherId >= 200 && weatherId < 300) return "⛈"; // Thunderstorm
  if (weatherId >= 300 && weatherId < 600) return "🌧"; // Drizzle/Rain
  if (weatherId >= 600 && weatherId < 700) return "❄"; // Snow
  if (weatherId >= 700 && weatherId < 800) return "🌫"; // Mist/Haze/Atmosphere
  if (weatherId == 800) return "☀"; // Clear sky
  if (weatherId > 800 && weatherId < 900) return "☁"; // Clouds
  return "🌍";
}

// 🎬 Map weather ID → video asset - UPDATED TO USE WEATHER ID
String getVideoForWeather(int weatherId) {
  if (weatherId >= 200 && weatherId < 300) return 'lib/assets/thunderstorm.mp4';
  if (weatherId >= 300 && weatherId < 600) return 'lib/assets/rainy.mp4';
  if (weatherId >= 600 && weatherId < 700) return 'lib/assets/snowy.mp4';
  if (weatherId >= 700 && weatherId < 800) return 'lib/assets/cloudy.mp4';
  if (weatherId == 800) return 'lib/assets/sunny.mp4';
  if (weatherId > 800 && weatherId < 900) return 'lib/assets/cloudy.mp4';
  return 'lib/assets/sunny.mp4';
}

// 🌍 Weather Model
@JsonSerializable(explicitToJson: true)
class WeatherData {
  final String city;
  final double temp;
  final double feelsLike;
  final int humidity;
  final double wind;
  final int cloudiness;
  final double rain;
  final String description;
  final int weatherId;
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
    required this.weatherId,
    required this.forecast,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) =>
      _$WeatherDataFromJson(json);

  Map<String, dynamic> toJson() => _$WeatherDataToJson(this);

  /// Pick forecast closest to current time and store weatherId
  factory WeatherData.fromApi(Map<String, dynamic> json) {
    final cityName = json['city']['name'];

    final now = DateTime.now();
    Map<String, dynamic> closest = json['list'][0];
    Duration minDiff =
        DateTime.parse(closest['dt_txt'] + "Z").toLocal().difference(now).abs();

    for (var item in json['list']) {
      final dt = DateTime.parse(item['dt_txt'] + "Z").toLocal();
      final diff = dt.difference(now).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = item;
      }
    }

    return WeatherData(
      city: cityName,
      temp: (closest['main']['temp'] as num).toDouble(),
      feelsLike: (closest['main']['feels_like'] as num).toDouble(),
      humidity: closest['main']['humidity'],
      wind: (closest['wind']['speed'] as num).toDouble(),
      cloudiness: closest['clouds']['all'],
      rain: (closest['rain']?['3h'] as num?)?.toDouble() ?? 0.0,
      description: closest['weather'][0]['description'],
      weatherId: closest['weather'][0]['id'],
      forecast: json['list'],
    );
  }
}

// 🔑 API Key
const String apiKey = "fbdb127778cc8f225b39771eaf89a5e7";

// 🌐 Fetch Weather
Future<WeatherData> fetchWeather(String city) async {
  final url =
      "https://api.openweathermap.org/data/2.5/forecast?q=$city&appid=$apiKey&units=metric";
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    return WeatherData.fromApi(jsonDecode(response.body));
  } else {
    throw Exception("Failed to load weather data");
  }
}

// 🌟 Providers
final darkModeProvider = StateProvider<bool>((ref) => false);
final cityProvider = StateProvider<String>((ref) => "");
final forecastIndexProvider = StateProvider<int>((ref) => 0);
final lastCityProvider = StateProvider<String>((ref) => "");

final weatherProvider =
    FutureProvider.family<WeatherData, String>((ref, city) async {
  if (city.isEmpty) throw Exception("Enter a city to get weather");
  return fetchWeather(city);
});

// 🎥 Video Widget
class WeatherVideo extends StatefulWidget {
  final String videoAsset;
  final double width;
  final double height;

  const WeatherVideo({
    super.key,
    required this.videoAsset,
    required this.width,
    required this.height,
  });

  @override
  State<WeatherVideo> createState() => _WeatherVideoState();
}

class _WeatherVideoState extends State<WeatherVideo> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.videoAsset)
      ..initialize().then((_) {
        setState(() {});
        _controller.setLooping(true);
        _controller.play();
      });
  }

  @override
  void didUpdateWidget(covariant WeatherVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoAsset != widget.videoAsset) {
      _controller.pause();
      _controller.dispose();
      _controller = VideoPlayerController.asset(widget.videoAsset)
        ..initialize().then((_) {
          setState(() {});
          _controller.setLooping(true);
          _controller.play();
        });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: Container(color: Colors.black12),
      );
    }
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: VideoPlayer(_controller),
      ),
    );
  }
}

void main() {
  runApp(const ProviderScope(child: WeatherApp()));
}

class WeatherApp extends ConsumerWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(darkModeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Weather App',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.lightBlue.shade50,
        cardColor: Colors.lightBlue[100],
        primaryColor: Colors.lightBlue,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        cardColor: Colors.deepPurple[100],
        primaryColor: Colors.deepPurple,
      ),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: const WeatherScreen(),
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
    final TextEditingController cityController =
        TextEditingController(text: city);

    return Scaffold(
      appBar: AppBar(
        title: const Text("🌦 Weather App"),
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
            // Search bar
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
            const SizedBox(height: 12),
            Expanded(
              child: weatherAsync.when(
                data: (weather) {
                  // ✅ compute closest index once per city
                  final now = DateTime.now();
                  int closestIndex = 0;
                  Duration minDiff = Duration(days: 9999);

                  for (int i = 0; i < weather.forecast.length; i++) {
                    final item = weather.forecast[i];
                    final dt = DateTime.parse(item['dt_txt'] + "Z").toLocal();
                    final diff = dt.difference(now).abs();
                    if (diff < minDiff) {
                      minDiff = diff;
                      closestIndex = i;
                    }
                  }

                  final lastCity = ref.read(lastCityProvider);
                  if (lastCity != weather.city) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      ref.read(forecastIndexProvider.notifier).state =
                          closestIndex;
                      ref.read(lastCityProvider.notifier).state = weather.city;
                    });
                  }

                  final forecastIndex = ref.watch(forecastIndexProvider);
                  final selected = weather.forecast[forecastIndex];
                  final selectedTime =
                      DateTime.parse(selected['dt_txt'] + "Z").toLocal();
                  final selectedTemp = selected['main']['temp'].toDouble();
                  final selectedDescription =
                      selected['weather'][0]['description'];
                  final selectedWeatherId = selected['weather'][0]['id'];
                  final videoAsset = getVideoForWeather(selectedWeatherId);

                  debugPrint(
                      "city=${weather.city} forecastIndex=$forecastIndex id=$selectedWeatherId asset=$videoAsset");

                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        // Upper card: current weather
                        Card(
                          elevation: 4,
                          color: isDark
                              ? Colors.deepPurple[100]
                              : Colors.lightBlue[100],
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  weather.city.toUpperCase(),
                                  style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "${weather.temp}°C ${getWeatherIcon(weather.weatherId)} ${weather.description}",
                                  style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepOrange),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 20,
                                  runSpacing: 10,
                                  children: [
                                    Text("💧 Humidity: ${weather.humidity}%",
                                        style: const TextStyle(
                                            color: Colors.black)),
                                    Text("💨 Wind: ${weather.wind} m/s",
                                        style: const TextStyle(
                                            color: Colors.black)),
                                    Text("☁ Cloudiness: ${weather.cloudiness}%",
                                        style: const TextStyle(
                                            color: Colors.black)),
                                    Text("🌧 Rain: ${weather.rain} mm",
                                        style: const TextStyle(
                                            color: Colors.black)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "5-day forecast (3-hour steps):",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 180,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: weather.forecast.length,
                            itemBuilder: (context, index) {
                              final item = weather.forecast[index];
                              final dt = DateTime.parse(item['dt_txt'] + "Z")
                                  .toLocal();
                              final temp = item['main']['temp'].toDouble();
                              final desc = item['weather'][0]['description'];
                              final weatherId = item['weather'][0]['id'];
                              final videoAsset = getVideoForWeather(weatherId);

                              return GestureDetector(
                                onTap: () => ref
                                    .read(forecastIndexProvider.notifier)
                                    .state = index,
                                child: Card(
                                  color: index == forecastIndex
                                      ? Colors.blueAccent
                                      : isDark
                                          ? Colors.deepPurple[200]
                                          : Colors.lightBlue[100],
                                  child: Container(
                                    width: 160,
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      children: [
                                        WeatherVideo(
                                            videoAsset: videoAsset,
                                            width: 140,
                                            height: 80),
                                        const SizedBox(height: 8),
                                        Text(
                                            "${dt.day}/${dt.month} ${dt.hour}:00",
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text("${temp.toStringAsFixed(1)}°C"),
                                        const SizedBox(height: 4),
                                        Text(
                                            "${getWeatherIcon(weatherId)} $desc",
                                            textAlign: TextAlign.center),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Slider(
                          value: ref.watch(forecastIndexProvider).toDouble(),
                          min: 0,
                          max: (weather.forecast.length - 1).toDouble(),
                          divisions: weather.forecast.length - 1,
                          label: "$forecastIndex",
                          onChanged: (value) => ref
                              .read(forecastIndexProvider.notifier)
                              .state = value.toInt(),
                        ),
                        const SizedBox(height: 10),
                        Card(
                          elevation: 3,
                          color: isDark
                              ? Colors.deepPurple[200]
                              : Colors.lightBlue[100],
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                WeatherVideo(
                                    videoAsset: videoAsset,
                                    width: double.infinity,
                                    height: 200),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Selected: ${selectedTime.toLocal()}",
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                              "Weather: ${getWeatherIcon(selectedWeatherId)} $selectedDescription",
                                              style: const TextStyle(
                                                  color: Colors.black)),
                                        ],
                                      ),
                                    ),
                                    const VerticalDivider(
                                      thickness: 1,
                                      color: Colors.black54,
                                      width: 20,
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            "💨 Wind: ${selected['wind']['speed']} m/s",
                                            style: const TextStyle(
                                                color: Colors.black)),
                                        Text("🌡 Temp: $selectedTemp °C",
                                            style: const TextStyle(
                                                color: Colors.black)),
                                        Text(
                                            "💧 Humidity: ${selected['main']['humidity']}%",
                                            style: const TextStyle(
                                                color: Colors.black)),
                                        Text(
                                            "🤔 Feels Like: ${selected['main']['feels_like']}°C",
                                            style: const TextStyle(
                                                color: Colors.black)),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
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

