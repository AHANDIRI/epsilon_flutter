import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'firebase_service.dart';
import 'file_card.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _files = [];
  bool _isLoadingFiles = false;
  bool _isUploading = false;
  double _uploadProgress = 0;
  String? _uploadingFileName;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoadingFiles = true);
    try {
      final files = await FirebaseService.getUserFiles();
      setState(() => _files = files);
    } catch (e) {
      _showSnack('Erreur lors du chargement des fichiers');
    } finally {
      setState(() => _isLoadingFiles = false);
    }
  }

  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.any,
      withData: true, // Obligatoire pour le web
    );

    if (result == null || result.files.isEmpty) return;

    final pickedFile = result.files.first;
    final fileSizeMb = pickedFile.size / (1024 * 1024);

    if (fileSizeMb > 50) {
      _showSnack('Le fichier dépasse la limite de 50 Mo');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _uploadingFileName = pickedFile.name;
    });

    // Simule une progression pendant l'upload
    _simulateProgress();

    try {
      await FirebaseService.uploadFile(pickedFile);
      if (mounted) {
        _showSnack('✅ Fichier uploadé avec succès !', isError: false);
        await _loadFiles();
      }
    } catch (e) {
      if (mounted) _showSnack('Erreur lors de l\'upload : ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0;
          _uploadingFileName = null;
        });
      }
    }
  }

  void _simulateProgress() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted || !_isUploading) return false;
      setState(() {
        _uploadProgress = (_uploadProgress + 0.05).clamp(0.0, 0.9);
      });
      return _isUploading;
    });
  }

  Future<void> _deleteFile(String fileId, String storagePath) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer le fichier ?'),
        content:
            const Text('Cette action est irréversible. Confirmer la suppression ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Supprimer',
                style: TextStyle(color: Colors.red.shade600)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseService.deleteFile(
          fileId: fileId, storagePath: storagePath);
      await _loadFiles();
      if (mounted) _showSnack('Fichier supprimé', isError: false);
    } catch (e) {
      if (mounted) _showSnack('Erreur lors de la suppression');
    }
  }

  Future<void> _signOut() async {
    await FirebaseService.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _showSnack(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final user = FirebaseService.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.cloud_done_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Mes Fichiers',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadFiles,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1A1A2E)),
            tooltip: 'Actualiser',
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'logout') _signOut();
            },
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Connecté en tant que',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(
                      user?.email ?? '',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 18, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Se déconnecter',
                        style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: cs.primary.withOpacity(0.15),
                child: Text(
                  (user?.email ?? 'U')[0].toUpperCase(),
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Upload banner
          if (_isUploading)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: cs.primary.withOpacity(0.08),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Upload de $_uploadingFileName...',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: cs.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${(_uploadProgress * 100).toInt()}%',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _uploadProgress,
                      backgroundColor: cs.primary.withOpacity(0.15),
                      color: cs.primary,
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),

          // Files list
          Expanded(
            child: _isLoadingFiles
                ? Center(
                    child: CircularProgressIndicator(color: cs.primary),
                  )
                : _files.isEmpty
                    ? _buildEmptyState(cs)
                    : RefreshIndicator(
                        onRefresh: _loadFiles,
                        color: cs.primary,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _files.length,
                          itemBuilder: (ctx, i) {
                            final file = _files[i];
                            return FileCard(
                              file: file,
                              onDelete: () => _deleteFile(
                                file['id'].toString(),
                                file['storage_path'] ?? '',
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUploading ? null : _pickAndUploadFile,
        backgroundColor: _isUploading ? Colors.grey : cs.primary,
        icon: const Icon(Icons.upload_file_rounded, color: Colors.white),
        label: const Text(
          'Uploader un fichier',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.folder_open_rounded,
              size: 44,
              color: cs.primary.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Aucun fichier pour le moment',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Appuie sur le bouton pour uploader\nton premier fichier',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, height: 1.5),
          ),
        ],
      ),
    );
  }
}