import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FileCard extends StatelessWidget {
  final Map<String, dynamic> file;
  final VoidCallback onDelete;

  const FileCard({
    super.key,
    required this.file,
    required this.onDelete,
  });

  String _formatSize(dynamic bytes) {
    if (bytes == null) return '—';
    final b = (bytes is int) ? bytes : int.tryParse(bytes.toString()) ?? 0;
    if (b < 1024) return '$b o';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} Ko';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '—';
    try {
      final dt = DateTime.parse(dateStr.toString()).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '—';
    }
  }

  IconData _getFileIcon(String? mimeType, String? fileName) {
    final mime = mimeType ?? '';
    final name = fileName?.toLowerCase() ?? '';

    if (mime.startsWith('image/')) return Icons.image_rounded;
    if (mime.startsWith('video/')) return Icons.video_file_rounded;
    if (mime.startsWith('audio/')) return Icons.audio_file_rounded;
    if (mime.contains('pdf')) return Icons.picture_as_pdf_rounded;
    if (mime.contains('spreadsheet') ||
        name.endsWith('.xlsx') ||
        name.endsWith('.csv')) return Icons.table_chart_rounded;
    if (mime.contains('presentation') || name.endsWith('.pptx')) {
      return Icons.slideshow_rounded;
    }
    if (mime.contains('word') || name.endsWith('.docx')) {
      return Icons.description_rounded;
    }
    if (mime.contains('zip') || mime.contains('archive')) {
      return Icons.folder_zip_rounded;
    }
    if (mime.contains('text/') || name.endsWith('.txt')) {
      return Icons.text_snippet_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  Color _getFileColor(String? mimeType) {
    final mime = mimeType ?? '';
    if (mime.startsWith('image/')) return Colors.purple;
    if (mime.startsWith('video/')) return Colors.blue;
    if (mime.startsWith('audio/')) return Colors.pink;
    if (mime.contains('pdf')) return Colors.red;
    if (mime.contains('spreadsheet')) return Colors.green;
    if (mime.contains('presentation')) return Colors.orange;
    if (mime.contains('word')) return const Color(0xFF2B6CB0);
    if (mime.contains('zip')) return Colors.amber.shade700;
    return Colors.grey.shade600;
  }

  @override
  Widget build(BuildContext context) {
    final fileName = file['nom'] ?? 'Fichier sans nom';
    final mimeType = file['type_mime'] as String?;
    final icon = _getFileIcon(mimeType, fileName);
    final color = _getFileColor(mimeType);
    final url = file['url'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          fileName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Color(0xFF1A1A2E),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                _Tag(
                  label: _formatSize(file['taille']),
                  icon: Icons.data_usage_rounded,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Tag(
                    label: _formatDate(file['created_at']),
                    icon: Icons.schedule_rounded,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'delete') onDelete();
            if (v == 'copy' && url != null) {
              await Clipboard.setData(ClipboardData(text: url));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Lien copié dans le presse-papier'),
                    backgroundColor: Colors.green.shade700,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            }
          },
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'copy',
              child: Row(
                children: [
                  Icon(Icons.link_rounded, size: 18, color: Colors.blue),
                  SizedBox(width: 10),
                  Text('Copier le lien'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline_rounded,
                      size: 18, color: Colors.red),
                  SizedBox(width: 10),
                  Text('Supprimer', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final IconData icon;

  const _Tag({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: Colors.grey.shade400),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}