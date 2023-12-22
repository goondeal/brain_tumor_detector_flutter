import 'dart:io';
import 'package:logger/logger.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brain-tumor Detector',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Brain-tumor Detector'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final IMAGE_SIZE = 240;
  bool _modelIsLoaded = false;
  bool _predecting = false;
  List _result = [];
  File? _selectedImage;
  final _picker = ImagePicker();
  Interpreter? _model;
  var logger = Logger(
    printer: PrettyPrinter(),
  );

  @override
  void initState() {
    super.initState();
    loadModelTfl();
  }

  void loadModelTfl() {
    Interpreter.fromAsset('assets/model.tflite').then((value) {
      _model = value;
      setState(() => _modelIsLoaded = true);
      logger.d('Model loaded value = $_model');
    }).catchError((err) {
      logger.d('Model loaded err = $err');
    });
  }

  List<List<List<double>>> imageToByteListFloat32(
    img.Image image,
    int inputSize,
  ) {
    logger.d('image width, height = (${image.width}, ${image.height})');
    final List<List<List<double>>> firstList = [];
    for (var i = 0; i < inputSize; i++) {
      final List<List<double>> secondList = [];
      for (var j = 0; j < inputSize; j++) {
        var pixel = image.getPixel(i, j);
        secondList.add([pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0]);
      }
      firstList.add(secondList);
    }
    return firstList;
  }

  void _classifyImage(File image) {
    setState(() => _predecting = true);
    logger.d('img path = ${image.path}');
    final int startTime = DateTime.now().millisecondsSinceEpoch;
    img
        .decodeImageFile(image.path)
        .then((value) =>
            img.copyResize(value!, width: IMAGE_SIZE, height: IMAGE_SIZE))
        .then((value) => imageToByteListFloat32(value, IMAGE_SIZE))
        .then((value) {
      if (_model != null) {
        var output = [
          [0.0]
        ];
        logger.d('output = $output');
        _model!.run([value], output);
        final int endTime = DateTime.now().millisecondsSinceEpoch;
        logger.d('inference took: ${endTime - startTime} ms');
        logger.d('output = $output');
        final label = output[0][0].round();
        // final confidence = label == 1 ? output[0][0] : 1 - output[0][0];
        setState(() {
          _result = [
            {
              'label': label == 1 ? 'Yes' : 'No',
              // 'confidence': '${(confidence * 100).toStringAsFixed(2)} %'
            }
          ];
        });
      } else {
        logger.d('model is null');
      }
    }).whenComplete(() => setState(() => _predecting = false));
  }

  Future _uploadImage() async {
    final XFile? pickedImage = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    final file = File(pickedImage!.path);
    setState(() {
      _selectedImage = file;
    });
    _classifyImage(file);
  }

  final _resultsTextStyle = const TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 20.0,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue[400],
      ),
      body: Center(
        child: _modelIsLoaded
            ? ListView(
                children: <Widget>[
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        margin: const EdgeInsets.all(16.0),
                        width: 300.0,
                        height: 300.0,
                        color: Colors.grey[100],
                        child: _selectedImage != null
                            ? Image.file(_selectedImage!)
                            : const Center(child: Text('No Image Selected')),
                      ),
                      FilledButton(
                        onPressed: _uploadImage,
                        style: ButtonStyle(
                          backgroundColor: MaterialStateProperty.resolveWith(
                              (states) => Colors.blue[800]),
                          textStyle: MaterialStateProperty.resolveWith(
                              (states) => const TextStyle(color: Colors.white)),
                        ),
                        child: const Text(
                          'Upload Image',
                          style: TextStyle(fontSize: 16.0),
                        ),
                      )
                    ],
                  ),
                  // _result.isNotEmpty
                  Container(
                    height: 300.0,
                    child: _predecting
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.max,
                            children: _result.isNotEmpty
                                ? _result
                                    .map(
                                      (value) => Card(
                                        child: Container(
                                          margin: const EdgeInsets.all(12.0),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Result:  ${value['label']}",
                                                style: _resultsTextStyle,
                                              ),
                                              // const SizedBox(height: 16.0),
                                              // Text(
                                              //     "Confidence:  ${value['confidence']}",
                                              //     style: _resultsTextStyle),
                                            ],
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList()
                                : [],
                          ),
                  ),
                ],
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
