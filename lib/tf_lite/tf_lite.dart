import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class EmotionDetectorScreen extends StatefulWidget {
  const EmotionDetectorScreen({super.key});

  @override
  State<EmotionDetectorScreen> createState() => _EmotionDetectorScreenState();
}

class _EmotionDetectorScreenState extends State<EmotionDetectorScreen> {
  CameraController? cameraController;
  Interpreter? _interpreter;
  List<String>? _labels;
  File? image;
  String? result;
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadModel();
    _loadLabels();

  }



  Future<void> _loadLabels() async {
    try {
      final labelData = await DefaultAssetBundle.of(
        context,
      ).loadString('assets/labels.txt');
      _labels =
          labelData
              .split('\n')
              .where((label) => label.trim().isNotEmpty)
              .toList();
      if (kDebugMode) print('Loaded labels: $_labels');
    } catch (e) {
      if (kDebugMode) print('Error loading labels: $e');
      _labels = ['Unknown'];
    }
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/tflite_model.tflite');
      setState(() {});
    } catch (e) {
      if (kDebugMode) print('Error loading model: $e');
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Select Image Source',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: Text('Camera', style: GoogleFonts.poppins()),
                  onTap: () {
                    Navigator.pop(context);
                    _captureImageFromCamera();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: Text('Gallery', style: GoogleFonts.poppins()),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromGallery();
                  },
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _captureImageFromCamera() async {
    if (cameraController == null || !cameraController!.value.isInitialized) {
      return;
    }

    try {
      setState(() => isProcessing = true);
      final XFile file = await cameraController!.takePicture();
      setState(() {
        image = File(file.path);
        result = null;
      });
      await _detectEmotion();
    } catch (e) {
      if (kDebugMode) print('Error capturing image: $e');
      setState(() {
        result = 'Error capturing image';
      });
    } finally {
      setState(() => isProcessing = false);
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      setState(() => isProcessing = true);
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile != null) {
        setState(() {
          image = File(pickedFile.path);
          result = null;
        });
        await _detectEmotion();
      }
    } catch (e) {
      if (kDebugMode) print('Error picking image: $e');
      setState(() {
        result = 'Error picking image';
      });
    } finally {
      setState(() => isProcessing = false);
    }
  }

  Future<void> _detectEmotion() async {
    if (_interpreter == null || image == null) return;

    try {
      final imageBytes = await image!.readAsBytes();
      final decodedImage = img.decodeImage(imageBytes)!;
      final input = await _preprocessImage(decodedImage);

      final outputShape = _interpreter!.getOutputTensor(0).shape;
      var output = List<double>.filled(
        outputShape[1],
        0.0,
      ).reshape(outputShape);

      _interpreter!.run(input, output);
      List<double> outputList =
          (output[0] as List).map((e) => e as double).toList();

      if (kDebugMode) {
        print('Model output: $outputList');
        print('Labels: $_labels');
      }

      double maxScore = outputList.reduce((a, b) => a > b ? a : b);
      int maxScoreIndex = outputList.indexOf(maxScore);

      if (maxScoreIndex >= 0 && maxScoreIndex < _labels!.length) {
        String detectedEmotion = _labels![maxScoreIndex].toLowerCase();
        if (kDebugMode) {
          print(
            'Detected emotion: $detectedEmotion (Index: $maxScoreIndex, Score: $maxScore)',
          );
        }
        setState(() {
          if (detectedEmotion.contains('sad')) {
            result = 'Angry';
          } else if (detectedEmotion.contains('happy')) {
            result = 'Happy';
          } else if (detectedEmotion.contains('angry')) {
            result = 'Happy';
          } else if (detectedEmotion.contains('shocked')) {
            result = 'Shocked';
          } else {
            result = 'Neutral';
          }
        });
      } else {
        setState(() {
          result = 'Unknown emotion';
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error during inference: $e');
      setState(() {
        result = 'Error detecting emotion';
      });
    }
  }

  Future<List<List<List<List<double>>>>> _preprocessImage(
    img.Image image,
  ) async {
    final resizedImage = img.copyResize(image, width: 224, height: 224);
    final input = List.generate(
      1,
      (_) => List.generate(
        224,
        (y) => List.generate(224, (x) {
          final pixel = resizedImage.getPixel(x, y);
          return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
        }),
      ),
    );
    return input;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A82FB), Color(0xFFFC5C7D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'Emotion Detector',
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              // Image Container
              Expanded(
                child: Center(
                  child: Container(
                    height: 300,
                    width: 300,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      // ignore: deprecated_member_use
                      color: Colors.white.withOpacity(0.2),
                    ),
                    child:
                        isProcessing
                            ? const SpinKitCircle(
                              color: Colors.white,
                              size: 50.0,
                            )
                            : image == null
                            ? const Icon(
                              Icons.image,
                              size: 100,
                              color: Colors.white70,
                            )
                            : ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.file(image!, fit: BoxFit.cover),
                            ),
                  ),
                ),
              ),
              // Result Display
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Text(
                  result ?? 'Click to detect emotion',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    color: getEmotionColor(result ?? ''),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              // Capture Button
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: GestureDetector(
                  onTap: _showImageSourceDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                    decoration: BoxDecoration(
                      // ignore: deprecated_member_use
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          // ignore: deprecated_member_use
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Text(
                      'Capture Image',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color getEmotionColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
        return Colors.yellow;
      case 'Angry':
        return Colors.red;
      case 'Shocked':
        return Colors.white;
      default:
        return Colors.white;
    }
  }

  @override
  void dispose() {
    cameraController?.dispose();
    _interpreter?.close();
    super.dispose();
  }
}
