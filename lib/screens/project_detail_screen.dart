import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:share_plus/share_plus.dart';
import '../models/project.dart';
import '../widgets/comparison_slider.dart';
import 'ghost_camera_screen.dart';

class ProjectDetailScreen extends StatefulWidget {
  final PhotoProject project;
  final List<CameraDescription> cameras;

  const ProjectDetailScreen({
    super.key,
    required this.project,
    required this.cameras,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  final Set<String> _selectedPhotos = {};
  bool _isCompareMode = false;
  int _compareAfterIndex = 0;

  void _toggleSelect(String path) {
    setState(() {
      if (_selectedPhotos.contains(path)) {
        _selectedPhotos.remove(path);
      } else {
        _selectedPhotos.add(path);
      }
    });
  }

  Future<void> _deleteSelectedPhotos() async {
    final deleteList = _selectedPhotos.toList();
    final containsOriginal = deleteList.contains(widget.project.originalImportedPath);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF242424),
        title: const Text("Fotoğrafları Sil"),
        content: Text(
          containsOriginal
              ? "Orijinal fotoğraf galerinizde korunur fakat bu projeden kaldırılır. Çekilen diğer kopyalar diskten silinecektir. Onaylıyor musunuz?"
              : "Seçilen fotoğraflar diskten tamamen silinecektir. Onaylıyor musunuz?",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("İptal", style: TextStyle(color: Colors.white70))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Sil", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    for (final path in deleteList) {
      if (path != widget.project.originalImportedPath) {
        final file = File(path);
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (_) {}
        }
        widget.project.capturedPaths.remove(path);
      }
    }

    setState(() {
      _selectedPhotos.clear();
    });
  }

  Future<void> _sharePhotos() async {
    final targets = _selectedPhotos.isEmpty ? widget.project.allPhotos : _selectedPhotos.toList();
    final xFiles = targets.map((p) => XFile(p)).toList();
    await Share.shareXFiles(xFiles, text: 'Fotoğraf Serisi Karşılaştırması');
  }

  @override
  Widget build(BuildContext context) {
    final allPhotos = widget.project.allPhotos;
    final hasMultiplePhotos = widget.project.capturedPaths.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Proje Detayı"),
        actions: [
          if (hasMultiplePhotos)
            IconButton(
              icon: Icon(_isCompareMode ? Icons.grid_view : Icons.compare, color: Colors.amber),
              tooltip: _isCompareMode ? "Izgara Görünümü" : "Karşılaştırma Modu",
              onPressed: () => setState(() => _isCompareMode = !_isCompareMode),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isCompareMode && hasMultiplePhotos
                ? Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: BeforeAfterSlider(
                              beforeImagePath: widget.project.originalImportedPath,
                              afterImagePath: widget.project.capturedPaths[_compareAfterIndex],
                            ),
                          ),
                        ),
                      ),
                      if (widget.project.capturedPaths.length > 1)
                        SizedBox(
                          height: 60,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: widget.project.capturedPaths.length,
                            itemBuilder: (ctx, i) => GestureDetector(
                              onTap: () => setState(() => _compareAfterIndex = i),
                              child: Container(
                                margin: const EdgeInsets.all(4),
                                width: 50,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: _compareAfterIndex == i ? Colors.amber : Colors.transparent,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.file(File(widget.project.capturedPaths[i]), fit: BoxFit.cover),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: allPhotos.length,
                    itemBuilder: (context, index) {
                      final photoPath = allPhotos[index];
                      final isOriginal = photoPath == widget.project.originalImportedPath;
                      final isSelected = _selectedPhotos.contains(photoPath);

                      return GestureDetector(
                        onTap: () => _toggleSelect(photoPath),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(File(photoPath), fit: BoxFit.cover),
                            ),
                            if (isOriginal)
                              Positioned(
                                bottom: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(6)),
                                  child: const Text("Orijinal", style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Icon(
                                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                color: isSelected ? Colors.blueAccent : Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.camera_alt, color: Colors.white),
                  label: const Text("Tekrar Çek", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final newPath = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GhostCameraScreen(
                          referencePhotoPath: widget.project.originalImportedPath,
                          cameras: widget.cameras,
                        ),
                      ),
                    );
                    if (newPath != null) {
                      setState(() {
                        widget.project.capturedPaths.add(newPath);
                      });
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.white),
                  onPressed: _sharePhotos,
                ),
                if (_selectedPhotos.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: _deleteSelectedPhotos,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}