import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── AUTH ────────────────────────────────────────────────────────────────

  static Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  static Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }

  static User? get currentUser => _auth.currentUser;

  // ─── FILE UPLOAD ─────────────────────────────────────────────────────────

  /// Upload un fichier dans Firebase Storage
  /// Retourne l'URL publique du fichier uploadé
  static Future<UploadResult> uploadFile(PlatformFile pickedFile) async {
    final user = currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    final fileName = pickedFile.name;
    final mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = 'uploads/${user.uid}/$timestamp\_$fileName';

    // Upload dans le bucket
    final ref = _storage.ref().child(storagePath);
    
    if (kIsWeb) {
      if (pickedFile.bytes == null) throw Exception('Fichier vide sur le web');
      await ref.putData(
        pickedFile.bytes!,
        SettableMetadata(contentType: mimeType),
      );
    } else {
      if (pickedFile.path == null) throw Exception('Chemin du fichier introuvable');
      await ref.putFile(
        File(pickedFile.path!),
        SettableMetadata(contentType: mimeType),
      );
    }

    // Récupère l'URL publique
    final publicUrl = await ref.getDownloadURL();

    // Enregistre les métadonnées en base de données Firestore
    await _firestore.collection('fichiers').add({
      'user_id': user.uid,
      'nom': fileName,
      'storage_path': storagePath,
      'url': publicUrl,
      'taille': pickedFile.size,
      'type_mime': mimeType,
      'created_at': FieldValue.serverTimestamp(),
    });

    return UploadResult(url: publicUrl, fileName: fileName);
  }

  /// Récupère la liste des fichiers de l'utilisateur connecté
  static Future<List<Map<String, dynamic>>> getUserFiles() async {
    final user = currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    final querySnapshot = await _firestore
        .collection('fichiers')
        .where('user_id', isEqualTo: user.uid)
        .get();

    final docs = querySnapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id; // Injecter l'ID du document pour la suppression
      return data;
    }).toList();

    // Tri en local pour éviter de devoir créer un index composite dans Firebase
    docs.sort((a, b) {
      final aDate = (a['created_at'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = (b['created_at'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return docs;
  }

  /// Supprime un fichier
  static Future<void> deleteFile({
    required String fileId,
    required String storagePath,
  }) async {
    // Supprimer de Storage (on ignore l'erreur si le fichier a déjà été supprimé manuellement)
    try {
      await _storage.ref().child(storagePath).delete();
    } catch (e) {
      print('Fichier introuvable dans Storage, poursuite de la suppression... $e');
    }

    // Supprimer de Firestore
    try {
      await _firestore.collection('fichiers').doc(fileId).delete();
    } catch (e) {
      print('Document introuvable dans Firestore... $e');
    }
  }
}

class UploadResult {
  final String url;
  final String fileName;

  UploadResult({required this.url, required this.fileName});
}
