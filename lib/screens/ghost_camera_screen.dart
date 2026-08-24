import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class GhostCameraScreen extends StatefulWidget {
  final String referencePhotoPath;
  final List<CameraDescription> cameras;

  const GhostCameraScreen({
    super.key,
    required this.referencePhotoPath,
    required this.cameras,
  });

  @override
  State<GhostCameraScreen> createState() => _GhostCameraScreenState();
}

class _GhostCameraScreenState extends State<GhostCameraScreen> {
  CameraController? _controller;
  int _currentBackCameraIndex = 0;
  List<CameraDescription> _backCameras = [];

  double _opacity = 0.5;
  double? _targetAspectRatio;
  bool _isProcessing = false;
  bool _highContrastMono = true;
  String? _capturedTempPath;

  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _currentZoom = 1.0;

  @override
  void initState() {
    super.initState();
    _backCameras = widget.cameras
        .where((c) => c.lensDirection == CameraLensDirection.back)
        .toList();
    if (_backCameras.isEmpty) _backCameras = widget.cameras;

    _initImage();
    _initCamera(_currentBackCameraIndex);
  }

  Future<void> _initImage() async {
    final imageFile = File(widget.referencePhotoPath);
    final decodedImage = await decodeImageFromList(await imageFile.readAsBytes());
    if (mounted) {
      setState(() {
        _targetAspectRatio = decodedImage.width / decodedImage.height;
      });
    }
  }

  Future<void> _initCamera(int index) async {
    if (_backCameras.isEmpty) return;

    if (_controller != null) {
      await _controller!.dispose();
    }

    _controller = CameraController(
      _backCameras[index],
      ResolutionPreset.max,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      _minZoom = await _controller!.getMinZoomLevel();
      _maxZoom = await _controller!.getMaxZoomLevel();
      _currentZoom = _minZoom;
      await _controller!.setZoomLevel(_currentZoom);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Kamera başlatma hatası: $e");
    }
  }

  Future<void> _switchPhysicalLens() async {
    if (_backCameras.length < 2) return;
    setState(() {
      _currentBackCameraIndex = (_currentBackCameraIndex + 1) % _backCameras.length;
    });
    await _initCamera(_currentBackCameraIndex);
  }

  Future<void> _setZoom(double zoom) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final target = zoom.clamp(_minZoom, _maxZoom);
    await _controller!.setZoomLevel(target);
    setState(() => _currentZoom = target);
  }

  Future<void> _captureToPreview() async {
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) return;

    setState(() => _isProcessing = true);
    try {
      final XFile raw = await _controller!.takePicture();
      setState(() {
        _capturedTempPath = raw.path;
      });
    } catch (e) {
      debugPrint("Çekim hatası: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _confirmSavePhoto() async {
    if (_capturedTempPath == null) return;

    setState(() => _isProcessing = true);
    String finalPath = _capturedTempPath!;

    try {
      // 1. Kalıcı yerel kopyayı uygulama belgeler klasörüne al
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = "rephoto_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final persistentPath = p.join(appDir.path, fileName);
      final persistentFile = await File(_capturedTempPath!).copy(persistentPath);
      finalPath = persistentFile.path;

      // 2. Fotoğrafı telefonun resmi galerisine (Pictures / DCIM) kaydet
      await Gal.putImage(finalPath, album: "RePhoto");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Fotoğraf galeriye ve projeye başarıyla kaydedildi!"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint("Galeriye kaydetme istisnası: $e");
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
        Navigator.pop(context, finalPath);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  static const List<double> _highContrastMatrix = <double>[
    1.6, 1.6, 1.6, 0, -130,
    1.6, 1.6, 1.6, 0, -130,
    1.6, 1.6, 1.6, 0, -130,
    0,   0,   0,   1, 0,
  ];

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized || _targetAspectRatio == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }

    final isLandscape = _targetAspectRatio! > 1.0;

    // Önizleme ve Kaydetme Onay Ekranı
    if (_capturedTempPath != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: _targetAspectRatio!,
                  child: Image.file(File(_capturedTempPath!), fit: BoxFit.contain),
                ),
              ),
              Positioned(
                bottom: 24,
                left: 20,
                right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    FloatingActionButton.extended(
                      heroTag: "retake",
                      backgroundColor: Colors.redAccent,
                      icon: const Icon(Icons.replay, color: Colors.white),
                      label: const Text("Yeniden Çek", style: TextStyle(color: Colors.white)),
                      onPressed: () => setState(() => _capturedTempPath = null),
                    ),
                    FloatingActionButton.extended(
                      heroTag: "save",
                      backgroundColor: Colors.green.shade600,
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text("Kaydet", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      onPressed: _isProcessing ? null : _confirmSavePhoto,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Canlı Kamera Ekranı
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: _targetAspectRatio!,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(_controller!),
                    Opacity(
                      opacity: _opacity,
                      child: _highContrastMono
                          ? ColorFiltered(
                              colorFilter: const ColorFilter.matrix(_highContrastMatrix),
                              child: Image.file(File(widget.referencePhotoPath), fit: BoxFit.cover),
                            )
                          : Image.file(File(widget.referencePhotoPath), fit: BoxFit.cover),
                    ),
                  ],
                ),
              ),
            ),

            // Üst Bar
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        _highContrastMono ? Icons.contrast : Icons.color_lens,
                        color: _highContrastMono ? Colors.amber : Colors.white70,
                      ),
                      tooltip: "Yüksek Kontrast",
                      onPressed: () => setState(() => _highContrastMono = !_highContrastMono),
                    ),
                    if (_backCameras.length > 1)
                      IconButton(
                        icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                        tooltip: "Lens Değiştir",
                        onPressed: _switchPhysicalLens,
                      ),
                  ],
                ),
              ),
            ),

            // Şeffaflık Slider'ı (Sol)
            Positioned(
              top: 70,
              left: 12,
              bottom: isLandscape ? 30 : 120,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.opacity, color: Colors.amber, size: 18),
                  Expanded(
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Slider(
                        value: _opacity,
                        min: 0.1,
                        max: 0.9,
                        activeColor: Colors.amber,
                        inactiveColor: Colors.white24,
                        onChanged: (val) => setState(() => _opacity = val),
                      ),
                    ),
                  ),
                  Text("${(_opacity * 100).toInt()}%", style: const TextStyle(color: Colors.white70, fontSize: 10)),
                ],
              ),
            ),

            // Zoom Slider'ı (Sağ)
            Positioned(
              top: 70,
              right: isLandscape ? 90 : 12,
              bottom: isLandscape ? 30 : 120,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.zoom_in, color: Colors.blueAccent, size: 18),
                  Expanded(
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Slider(
                        value: _currentZoom.clamp(_minZoom, _maxZoom),
                        min: _minZoom,
                        max: _maxZoom,
                        activeColor: Colors.blueAccent,
                        inactiveColor: Colors.white24,
                        onChanged: _setZoom,
                      ),
                    ),
                  ),
                  Text("${_currentZoom.toStringAsFixed(1)}x", style: const TextStyle(color: Colors.white70, fontSize: 10)),
                ],
              ),
            ),

            // Hızlı Zoom Çipleri
            Positioned(
              bottom: isLandscape ? 20 : 110,
              left: 50,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_minZoom < 1.0)
                      _buildChip("${_minZoom.toStringAsFixed(1)}x", _minZoom),
                    _buildChip("1.0x", 1.0),
                    if (_maxZoom >= 2.0)
                      _buildChip("2.0x", 2.0),
                  ],
                ),
              ),
            ),

            // Deklanşör Butonu
            Positioned(
              right: isLandscape ? 20 : 0,
              left: isLandscape ? null : 0,
              bottom: isLandscape ? null : 20,
              top: isLandscape ? 0 : null,
              child: Align(
                alignment: isLandscape ? Alignment.centerRight : Alignment.bottomCenter,
                child: GestureDetector(
                  onTap: _isProcessing ? null : _captureToPreview,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: Colors.white24,
                    ),
                    child: _isProcessing
                        ? const Center(child: CircularProgressIndicator(color: Colors.white))
                        : const Center(child: CircleAvatar(radius: 28, backgroundColor: Colors.white)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, double val) {
    final isSelected = (_currentZoom - val).abs() < 0.15;
    return GestureDetector(
      onTap: () => _setZoom(val),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.amber : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}