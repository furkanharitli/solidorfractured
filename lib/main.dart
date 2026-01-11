import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Online Kırık Tespiti',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const FractureDetectionPage(),
    );
  }
}

class FractureDetectionPage extends StatefulWidget {
  const FractureDetectionPage({super.key});

  @override
  State<FractureDetectionPage> createState() => _FractureDetectionPageState();
}

class _FractureDetectionPageState extends State<FractureDetectionPage> {
  File? _image;
  String _result = "";
  String _confidence = "";
  bool _loading = false;
  bool _showGraphs = false;

  final ImagePicker _picker = ImagePicker();
  final String apiUrl = "https://normalorfractured-production.up.railway.app/predict";

  // Grafiklerin dosya yolları
  final List<String> _assetGraphs = [
    'assets/graph1.png',
    'assets/graph2.png',
    'assets/graph3.png',
  ];

  Future<void> uploadImageToServer(File imageFile) async {
    setState(() {
      _loading = true;
      _result = "";
      _confidence = "";
      _showGraphs = false;
    });

    try {
      var uri = Uri.parse(apiUrl);
      var request = http.MultipartRequest('POST', uri);

      var multipartFile = await http.MultipartFile.fromPath(
        'image', // Sunucu 'image' bekliyor
        imageFile.path,
        filename: 'upload.jpg',
        contentType: MediaType('image', 'jpeg'),
      );

      request.files.add(multipartFile);

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        try {
          var jsonResponse = jsonDecode(response.body);
          setState(() {
            _result = jsonResponse['prediction'] ??
                jsonResponse['class'] ??
                jsonResponse['result'] ??
                "Sonuç Alındı";

            if (jsonResponse['confidence'] != null) {
              _confidence = "%${(double.parse(jsonResponse['confidence'].toString()) * 100).toStringAsFixed(1)}";
            }
          });
        } catch (e) {
          setState(() {
            _result = response.body;
          });
        }
      } else {
        setState(() {
          _result = "HATA (${response.statusCode}):\n${response.body}";
        });
      }

    } catch (e) {
      setState(() {
        _result = "Bağlantı Hatası: $e";
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  pickImage() async {
    // Sadece Galeri Kaynağı
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile == null) return;

    setState(() {
      _image = File(pickedFile.path);
    });

    uploadImageToServer(_image!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Online Kırık Analizi'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 80),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_loading)
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 15),
                    Text("Sunucu analiz ediyor..."),
                  ],
                ),

              const SizedBox(height: 20),

              _image != null
                  ? Container(
                height: 250,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.shade300),
                  image: DecorationImage(
                    image: FileImage(_image!),
                    fit: BoxFit.cover,
                  ),
                ),
              )
                  : Column(
                children: [
                  Icon(Icons.add_photo_alternate, size: 80, color: Colors.blueGrey),
                  const SizedBox(height: 10),
                  const Text("Röntgen Fotoğrafı Yükle"),
                ],
              ),

              const SizedBox(height: 30),

              if (_result.isNotEmpty && !_loading)
                Column(
                  children: [
                    Card(
                      elevation: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      color: _result.contains("HATA") ? Colors.red.shade50 : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            Text(
                              _result.contains("HATA") ? "HATA" : "TANI SONUCU",
                              style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _result.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: _result.contains("HATA") ? 16 : 32,
                                fontWeight: FontWeight.bold,
                                color: _result.contains("HATA")
                                    ? Colors.red
                                    : (_result.toLowerCase().contains("fracture") || _result.toLowerCase().contains("kirik") ? Colors.red : Colors.green),
                              ),
                            ),
                            if (_confidence.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text("Güven Oranı: $_confidence", style: const TextStyle(fontSize: 18)),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Buton
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showGraphs = !_showGraphs;
                        });
                      },
                      icon: Icon(_showGraphs ? Icons.keyboard_arrow_up : Icons.bar_chart),
                      label: Text(_showGraphs ? "Grafikleri Gizle" : "Analiz Grafiklerini Göster"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),

                    // Grafikler
                    if (_showGraphs)
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: _assetGraphs.map((path) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Image.asset(
                                      path,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) {
                                        return const Padding(
                                          padding: EdgeInsets.all(20.0),
                                          child: Text("Grafik yüklenemedi.\nAssets klasörünü kontrol edin.", textAlign: TextAlign.center),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),

      // Tek Buton: Galeri
      floatingActionButton: FloatingActionButton.extended(
        onPressed: pickImage, // Direkt fonksiyonu çağır
        label: const Text("Fotoğraf Seç"),
        icon: const Icon(Icons.photo_library),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
    );
  }
}