import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'models/project.dart';
import 'screens/project_detail_screen.dart';

List<CameraDescription> globalCameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    globalCameras = await availableCameras();
  } catch (e) {
    debugPrint("Kamera başlatılamadı: $e");
  }
  runApp(MaterialApp(
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        elevation: 0,
        centerTitle: true,
      ),
      colorScheme: ColorScheme.dark(
        primary: Colors.amber.shade600,
        surface: const Color(0xFF1E1E1E),
      ),
    ),
    home: const HomeScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<PhotoProject> _projects = [];
  final Set<String> _selectedProjectIds = {};
  bool _isSelectionMode = false;

  Future<void> _importNewPhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final newProject = PhotoProject(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        originalImportedPath: pickedFile.path,
        capturedPaths: [],
        createdAt: DateTime.now(),
      );

      setState(() {
        _projects.insert(0, newProject);
      });
    }
  }

  Future<void> _deleteSelectedProjects() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF242424),
        title: const Text("Projeleri Sil"),
        content: const Text(
          "Seçilen projeler ve uygulama üzerinden çekilen tüm fotoğraflar silinecektir. Orijinal galeri fotoğraflarınız korunur. Onaylıyor musunuz?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("İptal", style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Sil", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    for (final projectId in _selectedProjectIds) {
      final proj = _projects.firstWhere((p) => p.id == projectId);
      for (final capPath in proj.capturedPaths) {
        final file = File(capPath);
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (_) {}
        }
      }
    }

    setState(() {
      _projects.removeWhere((p) => _selectedProjectIds.contains(p.id));
      _selectedProjectIds.clear();
      _isSelectionMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSelectionMode ? "${_selectedProjectIds.length} Seçildi" : "Projeler",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: _selectedProjectIds.isEmpty ? null : _deleteSelectedProjects,
            ),
          if (!_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.checklist_rounded),
              onPressed: () => setState(() => _isSelectionMode = true),
            )
          else
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _isSelectionMode = false;
                _selectedProjectIds.clear();
              }),
            ),
        ],
      ),
      body: _projects.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library_outlined, size: 72, color: Colors.grey.shade700),
                  const SizedBox(height: 16),
                  Text("Henüz bir proje eklenmedi.", style: TextStyle(color: Colors.grey.shade400)),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: _projects.length,
              itemBuilder: (context, index) {
                final project = _projects[index];
                final isSelected = _selectedProjectIds.contains(project.id);

                return GestureDetector(
                  onLongPress: () {
                    setState(() {
                      _isSelectionMode = true;
                      _selectedProjectIds.add(project.id);
                    });
                  },
                  onTap: () async {
                    if (_isSelectionMode) {
                      setState(() {
                        if (isSelected) {
                          _selectedProjectIds.remove(project.id);
                        } else {
                          _selectedProjectIds.add(project.id);
                        }
                      });
                    } else {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProjectDetailScreen(
                            project: project,
                            cameras: globalCameras,
                          ),
                        ),
                      );
                      setState(() {});
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? Colors.blueAccent : project.statusColor,
                        width: isSelected ? 4 : 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: project.statusColor.withOpacity(0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            File(project.originalImportedPath),
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.75),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "${project.totalCount} Foto",
                                style: TextStyle(
                                  color: project.statusColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          if (_isSelectionMode)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Icon(
                                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                color: isSelected ? Colors.blueAccent : Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importNewPhoto,
        backgroundColor: Colors.amber.shade700,
        icon: const Icon(Icons.add_photo_alternate, color: Colors.black),
        label: const Text("Fotoğraf İçe Aktar", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }
}