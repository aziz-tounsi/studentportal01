import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border, TextSpan, BorderStyle;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/theme/app_theme.dart';

/// Simple bulk import screen - bypasses DataTable2 issues
class SimpleBulkImportScreen extends ConsumerStatefulWidget {
  const SimpleBulkImportScreen({super.key});

  @override
  ConsumerState<SimpleBulkImportScreen> createState() =>
      _SimpleBulkImportScreenState();
}

class _SimpleBulkImportScreenState
    extends ConsumerState<SimpleBulkImportScreen> {
  List<Map<String, String>> _parsedUsers = [];
  List<Map<String, String>> _createdUsers = [];
  List<String> _errors = [];
  bool _isLoading = false;
  bool _isImporting = false;
  String _status = '';
  int _successCount = 0;
  int _failCount = 0;

  // Available classes for enrollment
  List<Map<String, dynamic>> _availableClasses = [];
  Map<String, String> _classIdByName = {}; // Map class name to ID
  Map<String, List<String>> _classesByNiveau = {}; // Map niveau code to class IDs

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  // Available niveaux for selection
  List<Map<String, dynamic>> _availableNiveaux = [];

  Future<void> _loadClasses() async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) {
        debugPrint('BulkImport: No current user');
        return;
      }

      final userResp = await Supabase.instance.client
          .from('users')
          .select('school_id')
          .eq('id', currentUserId)
          .single();
      final schoolId = userResp['school_id'];
      debugPrint('BulkImport: School ID = $schoolId');

      if (schoolId == null) {
        debugPrint('BulkImport: No school ID for user');
        return;
      }

      // Load classes - try with join first, fallback to simple query
      List<dynamic> classesResp;
      try {
        classesResp = await Supabase.instance.client
            .from('classes')
            .select('id, name, niveau_id, niveaux(id, code, name)')
            .eq('school_id', schoolId)
            .order('name');
      } catch (e) {
        debugPrint('BulkImport: Join query failed, trying simple query: $e');
        classesResp = await Supabase.instance.client
            .from('classes')
            .select('id, name, niveau_id')
            .eq('school_id', schoolId)
            .order('name');
      }

      debugPrint('BulkImport: Raw classes response: $classesResp');

      // Load niveaux separately
      final niveauxResp = await Supabase.instance.client
          .from('niveaux')
          .select('id, code, name, display_order')
          .order('display_order');

      final classes = List<Map<String, dynamic>>.from(classesResp);
      final niveaux = List<Map<String, dynamic>>.from(niveauxResp);

      debugPrint('BulkImport: Loaded ${classes.length} classes, ${niveaux.length} niveaux');

      // Build niveau lookup by ID
      final niveauById = <String, Map<String, dynamic>>{};
      for (final n in niveaux) {
        niveauById[n['id'] as String] = n;
      }

      // Build class lookup maps
      final classIdByName = <String, String>{};
      final classesByNiveau = <String, List<String>>{};

      for (final c in classes) {
        final name = (c['name'] as String).toLowerCase();
        final id = c['id'] as String;
        classIdByName[name] = id;

        // Get niveau info - either from join or from lookup
        Map<String, dynamic>? niveauInfo = c['niveaux'] as Map<String, dynamic>?;
        if (niveauInfo == null && c['niveau_id'] != null) {
          niveauInfo = niveauById[c['niveau_id'] as String];
        }
        
        if (niveauInfo != null) {
          final niveauCode = niveauInfo['code'] as String? ?? '';
          classesByNiveau
              .putIfAbsent(niveauCode.toLowerCase(), () => [])
              .add(id);
        }
      }

      setState(() {
        _availableClasses = classes;
        _classIdByName = classIdByName;
        _classesByNiveau = classesByNiveau;
        _availableNiveaux = niveaux;
      });

      debugPrint('BulkImport: CLASS NAMES AVAILABLE:');
      for (final entry in classIdByName.entries) {
        debugPrint('  - "${entry.key}" -> ${entry.value}');
      }
    } catch (e, stack) {
      debugPrint('Error loading classes: $e');
      debugPrint('Stack: $stack');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Breadcrumb
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text('Utilisateurs', style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.chevron_right, size: 16, color: AppColors.textTertiary),
                ),
                Text('Importation en Masse', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ],
            ),
            const SizedBox(height: 20),
            // Title row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Importation en Masse',
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ajoutez des centaines d\'utilisateurs simultanément. Suivez les étapes ci-dessous pour garantir l\'intégrité de vos données.',
                        style: TextStyle(fontSize: 15, color: AppColors.textTertiary, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Retour à la liste'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Main grid: left (steps 1+2) / right (step 3 upload)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left column
                SizedBox(
                  width: 340,
                  child: Column(
                    children: [
                      _buildStep1Card(),
                      const SizedBox(height: 20),
                      _buildStep2Card(),
                    ],
                  ),
                ),
                const SizedBox(width: 28),
                // Right column
                Expanded(child: _buildStep3Card()),
              ],
            ),
            const SizedBox(height: 32),
            // Status / Preview / Results
            if (_status.isNotEmpty) ...[
              _buildStatusCard(),
              const SizedBox(height: 24),
            ],
            if (_parsedUsers.isNotEmpty) ...[
              _buildParsedUsersPreview(),
              const SizedBox(height: 24),
            ],
            if (_createdUsers.isNotEmpty) ...[
              _buildCreatedUsersSection(),
              const SizedBox(height: 24),
            ],
            if (_errors.isNotEmpty) _buildErrorsSection(),
            const SizedBox(height: 24),
            // Preview table
            _buildPreviewTable(),
            // Tip
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, color: Color(0xFFF59E0B), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 13, color: const Color(0xFF92400E), height: 1.5),
                        children: [
                          const TextSpan(text: 'Conseil : ', style: TextStyle(fontWeight: FontWeight.w700)),
                          const TextSpan(text: 'Après avoir importé, vous pourrez vérifier chaque ligne et corriger les erreurs éventuelles avant la validation finale.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // STEP 1: Download template
  // ═══════════════════════════════════════════════════
  Widget _buildStep1Card() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(child: Text('1', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 14))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Télécharger le modèle', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A))),
                    const SizedBox(height: 4),
                    Text(
                      'Utilisez notre structure prédéfinie pour éviter les erreurs de formatage lors de l\'import.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.textTertiary, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _downloadTemplate,
              icon: const Icon(Icons.download, size: 20),
              label: const Text('Télécharger .XLSX', style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 3,
                shadowColor: AppColors.primary.withOpacity(0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // STEP 2: Required columns
  // ═══════════════════════════════════════════════════
  Widget _buildStep2Card() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(child: Text('2', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 14))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Colonnes requises', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A))),
                    const SizedBox(height: 4),
                    Text(
                      'Votre fichier doit contenir exactement ces en-têtes de colonnes :',
                      style: TextStyle(fontSize: 12.5, color: AppColors.textTertiary, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildColumnRow('Nom complet', 'REQUIS', true),
          const SizedBox(height: 8),
          _buildColumnRow('Date naissance', 'OPTIONNEL', false),
          const SizedBox(height: 8),
          _buildColumnRow('Email', 'UNIQUE', true),
          const SizedBox(height: 8),
          _buildColumnRow('Classe', 'REQUIS', true),
          const SizedBox(height: 8),
          _buildColumnRow('Niveau', 'OPTIONNEL', false),
        ],
      ),
    );
  }

  Widget _buildColumnRow(String label, String badge, bool isRequired) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF334155))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isRequired ? AppColors.primary.withOpacity(0.1) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: isRequired ? AppColors.primary : AppColors.textTertiary,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // STEP 3: Upload zone
  // ═══════════════════════════════════════════════════
  Widget _buildStep3Card() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(child: Text('3', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 14))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Téléverser le fichier', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A))),
                    const SizedBox(height: 4),
                    Text(
                      'Glissez votre fichier complété ci-dessous pour lancer l\'analyse.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.textTertiary, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          // Dashed upload zone
          GestureDetector(
            onTap: _isLoading ? null : _pickFile,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 320),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.4),
                  width: 2,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              ),
              child: CustomPaint(
                painter: _DashedBorderPainter(color: AppColors.primary.withOpacity(0.35)),
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: _isLoading
                            ? Padding(
                                padding: const EdgeInsets.all(20),
                                child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
                              )
                            : Icon(Icons.cloud_upload_outlined, size: 40, color: AppColors.primary),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Glissez-déposez votre fichier ici',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Formats acceptés : .xlsx, .xls, .csv jusqu\'à 10 Mo',
                        style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                      ),
                      const SizedBox(height: 28),
                      OutlinedButton(
                        onPressed: _isLoading ? null : _pickFile,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Parcourir les fichiers', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Bottom file info bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border.withOpacity(0.5), style: BorderStyle.solid),
            ),
            child: Row(
              children: [
                Icon(Icons.description_outlined, color: AppColors.textTertiary, size: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _parsedUsers.isNotEmpty
                            ? '${_parsedUsers.length} utilisateur(s) prêt(s)'
                            : 'Aucun fichier sélectionné',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _parsedUsers.isNotEmpty ? AppColors.textPrimary : AppColors.textTertiary,
                          fontStyle: _parsedUsers.isEmpty ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                      if (_parsedUsers.isEmpty)
                        Text('Veuillez d\'abord choisir un fichier', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: (_isImporting || _parsedUsers.isEmpty) ? null : _importUsers,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (_parsedUsers.isEmpty) ? AppColors.primary.withOpacity(0.5) : AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withOpacity(0.4),
                    disabledForegroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    _isImporting ? 'Import en cours...' : 'Démarrer l\'importation',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // PREVIEW TABLE
  // ═══════════════════════════════════════════════════
  Widget _buildPreviewTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Aperçu du format attendu', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A))),
                Text('EXEMPLE DE DONNÉES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 1.5)),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.border.withOpacity(0.5)),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              headingRowHeight: 48,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 48,
              columns: const [
                DataColumn(label: Text('NOM COMPLET', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.8))),
                DataColumn(label: Text('DATE NAISSANCE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.8))),
                DataColumn(label: Text('ADRESSE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.8))),
                DataColumn(label: Text('GENRE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.8))),
                DataColumn(label: Text('NATIONALITÉ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.8))),
                DataColumn(label: Text('CLASSE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.8))),
              ],
              rows: [
                DataRow(cells: [
                  DataCell(Text('Jean Dupont', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                  DataCell(Text('12/05/2008', style: TextStyle(fontSize: 13, color: AppColors.textTertiary))),
                  DataCell(Text('12 rue de la Paix, Paris', style: TextStyle(fontSize: 13, color: AppColors.textTertiary))),
                  DataCell(Text('M', style: TextStyle(fontSize: 13, color: AppColors.textTertiary))),
                  DataCell(Text('Française', style: TextStyle(fontSize: 13, color: AppColors.textTertiary))),
                  DataCell(Text('3ème A', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary))),
                ]),
                DataRow(cells: [
                  DataCell(Text('Marie Curie', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                  DataCell(Text('07/11/2009', style: TextStyle(fontSize: 13, color: AppColors.textTertiary))),
                  DataCell(Text('45 avenue des Sciences, Lyon', style: TextStyle(fontSize: 13, color: AppColors.textTertiary))),
                  DataCell(Text('F', style: TextStyle(fontSize: 13, color: AppColors.textTertiary))),
                  DataCell(Text('Polonaise', style: TextStyle(fontSize: 13, color: AppColors.textTertiary))),
                  DataCell(Text('4ème B', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary))),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    Color bgColor = AppColors.primarySoft;
    Color textColor = AppColors.primary;
    IconData icon = Icons.info;

    if (_status.contains('Erreur') || _status.contains('échec')) {
      bgColor = AppColors.errorSoft;
      textColor = AppColors.error;
      icon = Icons.error;
    } else if (_status.contains('succès') || _status.contains('terminé')) {
      bgColor = AppColors.successSoft;
      textColor = AppColors.success;
      icon = Icons.check_circle;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _status,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParsedUsersPreview() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_parsedUsers.length} utilisateur(s) trouvé(s)',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cliquez sur × pour supprimer un utilisateur avant l\'import',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
              Row(
                children: [
                  if (_parsedUsers.length > 1)
                    TextButton.icon(
                      onPressed: _isImporting
                          ? null
                          : () {
                              setState(() {
                                _parsedUsers.clear();
                                _status = 'Liste vidée';
                              });
                            },
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: const Text('Tout supprimer'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.error),
                    ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isImporting || _parsedUsers.isEmpty
                        ? null
                        : _importUsers,
                    icon: _isImporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textOnPrimary,
                            ),
                          )
                        : const Icon(Icons.upload),
                    label: Text(
                      _isImporting
                          ? 'Import en cours...'
                          : 'Importer maintenant',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: AppColors.textOnPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.slate300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _parsedUsers.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: AppColors.slate200),
              itemBuilder: (context, index) {
                final user = _parsedUsers[index];
                final hasNiveau = user['niveau']?.isNotEmpty == true;
                final hasClass = user['className']?.isNotEmpty == true;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: user['role'] == 'student'
                        ? AppColors.warningSoft
                        : AppColors.border,
                    child: Icon(
                      user['gender'] == 'F' ? Icons.female : Icons.male,
                      color: user['role'] == 'student'
                          ? AppColors.warning
                          : AppColors.primary,
                    ),
                  ),
                  title: Text(
                    user['fullName'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user['email'] ?? ''),
                      if (hasNiveau || hasClass)
                        Text(
                          '${hasNiveau ? 'Niveau: ${user['niveau']}' : ''}${hasNiveau && hasClass ? ' • ' : ''}${hasClass ? 'Classe: ${user['className']}' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.success,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  isThreeLine: hasNiveau || hasClass,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: user['role'] == 'student'
                              ? AppColors.warningSoft
                              : AppColors.border,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          user['role'] == 'student' ? 'Étudiant' : 'Staff',
                          style: TextStyle(
                            fontSize: 12,
                            color: user['role'] == 'student'
                                ? AppColors.warning
                                : AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: AppColors.error,
                          size: 20,
                        ),
                        tooltip: 'Supprimer de la liste',
                        onPressed: _isImporting
                            ? null
                            : () {
                                setState(() {
                                  _parsedUsers.removeAt(index);
                                  _status =
                                      '${_parsedUsers.length} utilisateur(s) restant(s)';
                                });
                              },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatedUsersSection() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success),
              const SizedBox(width: 12),
              Text(
                '$_successCount utilisateur(s) créé(s) avec succès',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warningSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: AppColors.warning),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'IMPORTANT: Copiez ou téléchargez les identifiants ci-dessous. Les mots de passe ne seront plus accessibles après fermeture.',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            constraints: const BoxConstraints(maxHeight: 400),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.slate300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _createdUsers.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: AppColors.slate200),
              itemBuilder: (context, index) {
                final user = _createdUsers[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.successSoft,
                    child: const Icon(Icons.check, color: AppColors.success),
                  ),
                  title: Text(
                    user['fullName'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(user['email'] ?? ''),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.slate100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: SelectableText(
                          user['password'] ?? '',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: 'Copier mot de passe',
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: user['password'] ?? ''),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Mot de passe copié!'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              onPressed: _exportCredentials,
              icon: const Icon(Icons.download),
              label: const Text('Télécharger tous les identifiants (Excel)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorsSection() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error, color: AppColors.error),
              const SizedBox(width: 12),
              Text(
                '$_failCount erreur(s)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _errors.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '• ${_errors[index]}',
                  style: TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      setState(() {
        _isLoading = true;
        _status = 'Lecture du fichier...';
        _parsedUsers = [];
        _createdUsers = [];
        _errors = [];
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        final fileName = result.files.single.name.toLowerCase();
        final users = <Map<String, String>>[];

        if (fileName.endsWith('.csv')) {
          final content = String.fromCharCodes(bytes);
          final lines = content.split('\n');

          for (var i = 1; i < lines.length; i++) {
            final line = lines[i].trim();
            if (line.isEmpty) continue;

            final parts = line.split(',');
            if (parts.length < 2) continue;

            final fullName = parts[0].trim();
            final email = parts[1].trim();
            final phone = parts.length > 2 ? parts[2].trim() : '';
            final role = parts.length > 3
                ? parts[3].trim().toLowerCase()
                : 'student';
            final dateOfBirth = parts.length > 4 ? parts[4].trim() : '';
            final address = parts.length > 5 ? parts[5].trim() : '';
            final gender = parts.length > 6
                ? parts[6].trim().toUpperCase()
                : '';
            final nationality = parts.length > 7 ? parts[7].trim() : '';
            final niveau = parts.length > 8 ? parts[8].trim() : '';
            final className = parts.length > 9 ? parts[9].trim() : '';

            if (fullName.isNotEmpty && email.isNotEmpty) {
              users.add({
                'fullName': fullName,
                'email': email,
                'phone': phone,
                'role': role.isEmpty ? 'student' : role,
                'dateOfBirth': dateOfBirth,
                'address': address,
                'gender': gender,
                'nationality': nationality,
                'niveau': niveau,
                'className': className,
              });
            }
          }
        } else {
          final excel = Excel.decodeBytes(bytes);

          for (final table in excel.tables.keys) {
            final sheet = excel.tables[table]!;

            for (var i = 1; i < sheet.maxRows; i++) {
              final row = sheet.rows[i];
              if (row.isEmpty || row[0]?.value == null) continue;

              final fullName = row[0]?.value?.toString() ?? '';
              final email = row[1]?.value?.toString() ?? '';
              final phone = row.length > 2 ? row[2]?.value?.toString() : null;
              final role = row.length > 3
                  ? row[3]?.value?.toString() ?? 'student'
                  : 'student';
              final dateOfBirth = row.length > 4
                  ? row[4]?.value?.toString()
                  : null;
              final address = row.length > 5 ? row[5]?.value?.toString() : null;
              final gender = row.length > 6
                  ? row[6]?.value?.toString().toUpperCase()
                  : null;
              final nationality = row.length > 7
                  ? row[7]?.value?.toString()
                  : null;
              final niveau = row.length > 8 ? row[8]?.value?.toString() : null;
              final className = row.length > 9
                  ? row[9]?.value?.toString()
                  : null;

              if (fullName.isNotEmpty && email.isNotEmpty) {
                users.add({
                  'fullName': fullName,
                  'email': email,
                  'phone': phone ?? '',
                  'role': role.toLowerCase().isEmpty
                      ? 'student'
                      : role.toLowerCase(),
                  'dateOfBirth': dateOfBirth ?? '',
                  'address': address ?? '',
                  'gender': gender ?? '',
                  'nationality': nationality ?? '',
                  'niveau': niveau ?? '',
                  'className': className ?? '',
                });
              }
            }
            break;
          }
        }

        setState(() {
          _parsedUsers = users;
          _status = users.isEmpty
              ? 'Aucun utilisateur trouvé dans le fichier'
              : '${users.length} utilisateur(s) prêt(s) à importer';
          _isLoading = false;
        });
      } else {
        setState(() {
          _status = 'Aucun fichier sélectionné';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Erreur lors de la lecture: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _importUsers() async {
    if (_parsedUsers.isEmpty) return;

    setState(() {
      _isImporting = true;
      _status = 'Chargement des classes...';
      _createdUsers = [];
      _errors = [];
      _successCount = 0;
      _failCount = 0;
    });

    // Reload classes to ensure we have the latest data
    await _loadClasses();

    debugPrint(
      'BulkImport: Starting import with ${_classIdByName.length} classes loaded',
    );
    if (_classIdByName.isEmpty) {
      setState(() {
        _status = 'Erreur: Aucune classe trouvée dans la base de données';
        _isImporting = false;
      });
      return;
    }

    setState(() {
      _status = 'Import en cours...';
    });

    final adminClient = SupabaseConfig.adminClient;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    if (currentUserId == null) {
      setState(() {
        _status = 'Erreur: Non connecté';
        _isImporting = false;
      });
      return;
    }

    // Get school ID
    String? schoolId;
    try {
      final userResp = await Supabase.instance.client
          .from('users')
          .select('school_id')
          .eq('id', currentUserId)
          .single();
      schoolId = userResp['school_id'];
    } catch (e) {
      setState(() {
        _status = 'Erreur: Impossible de récupérer l\'école';
        _isImporting = false;
      });
      return;
    }

    for (var i = 0; i < _parsedUsers.length; i++) {
      final user = _parsedUsers[i];
      setState(
        () => _status =
            'Import ${i + 1}/${_parsedUsers.length}: ${user['fullName']}',
      );

      try {
        final password = _generatePassword();
        final code = await _generateCode(user['role'] ?? 'student');

        // Create auth user
        final authResp = await adminClient.auth.admin.createUser(
          AdminUserAttributes(
            email: user['email']!,
            password: password,
            emailConfirm: true,
          ),
        );

        final newUserId = authResp.user?.id;
        if (newUserId == null) throw Exception('Failed to create auth user');

        // Resolve class ID from niveau and class name
        String? classId;
        String? niveauCode = user['niveau'];
        final className = user['className'];

        debugPrint(
          'BulkImport: Processing ${user['fullName']} - niveau=$niveauCode, class=$className',
        );
        debugPrint(
          'BulkImport: Available classes (first 15): ${_classIdByName.keys.take(15).toList()}',
        );

        // Only try to find class if className is provided and not empty
        if (className != null && className.toString().trim().isNotEmpty) {
          final searchName = className.toString().toLowerCase().trim();

          // Step 1: Try exact name match
          classId = _classIdByName[searchName];
          debugPrint('BulkImport: Exact match for "$searchName": $classId');

          // Step 2: Try without spaces/dashes normalization
          if (classId == null) {
            final normalized = searchName.replaceAll(RegExp(r'[\s\-_]'), '');
            for (final entry in _classIdByName.entries) {
              final entryNormalized = entry.key.replaceAll(
                RegExp(r'[\s\-_]'),
                '',
              );
              if (entryNormalized == normalized) {
                classId = entry.value;
                debugPrint(
                  'BulkImport: Normalized match: "${entry.key}" -> $classId',
                );
                break;
              }
            }
          }

          // Step 3: Try contains match
          if (classId == null) {
            for (final entry in _classIdByName.entries) {
              if (entry.key.contains(searchName) ||
                  searchName.contains(entry.key)) {
                classId = entry.value;
                debugPrint(
                  'BulkImport: Contains match: "${entry.key}" -> $classId',
                );
                break;
              }
            }
          }

          if (classId == null) {
            debugPrint('BulkImport: NO MATCH FOUND for class "$searchName"');
          }
        }

        // Get niveau_id only if niveauCode is provided
        String? niveauId;
        if (niveauCode != null && niveauCode.toString().trim().isNotEmpty) {
          final niveauSearch = niveauCode.toString().toLowerCase().trim();
          final niveauInfo = _availableNiveaux.firstWhere(
            (n) => (n['code'] as String?)?.toLowerCase() == niveauSearch,
            orElse: () => <String, dynamic>{},
          );
          niveauId = niveauInfo['id'] as String?;
          debugPrint(
            'BulkImport: Found niveau_id=$niveauId for code=$niveauCode',
          );
        }

        // If class was found, get niveau from class if not already set
        if (classId != null && niveauId == null) {
          final classInfo = _availableClasses.firstWhere(
            (c) => c['id'] == classId,
            orElse: () => <String, dynamic>{},
          );
          final classNiveauInfo = classInfo['niveaux'] as Map<String, dynamic>?;
          if (classNiveauInfo != null) {
            niveauId = classNiveauInfo['id'] as String?;
            niveauCode ??= classNiveauInfo['code'] as String?;
          }
          niveauId ??= classInfo['niveau_id'] as String?;
        }

        debugPrint(
          'BulkImport: Final - classId=$classId, niveauCode=$niveauCode, niveauId=$niveauId',
        );

        // Insert profile with new fields
        // Convert date from DD/MM/YYYY to YYYY-MM-DD for PostgreSQL
        String? formattedDate;
        final rawDate = user['dateOfBirth'];
        if (rawDate != null && rawDate.isNotEmpty) {
          try {
            // Try DD/MM/YYYY format
            final parts = rawDate.split('/');
            if (parts.length == 3) {
              final day = parts[0].padLeft(2, '0');
              final month = parts[1].padLeft(2, '0');
              final year = parts[2];
              formattedDate = '$year-$month-$day';
            } else if (rawDate.contains('-')) {
              // Already in YYYY-MM-DD format
              formattedDate = rawDate;
            }
          } catch (e) {
            debugPrint('BulkImport: Date parse error for "$rawDate": $e');
          }
        }

        await adminClient.from('users').insert({
          'id': newUserId,
          'school_id': schoolId,
          'email': user['email'],
          'full_name': user['fullName'],
          'role': user['role'] ?? 'student',
          'phone': user['phone']?.isNotEmpty == true ? user['phone'] : null,
          'student_code': code,
          'date_of_birth': formattedDate,
          'address': user['address']?.isNotEmpty == true
              ? user['address']
              : null,
          'gender': user['gender']?.isNotEmpty == true ? user['gender'] : null,
          'nationality': user['nationality']?.isNotEmpty == true
              ? user['nationality']
              : null,
          'niveau_code': niveauCode,
          'niveau_id': niveauId,
          'initial_password': password, // Store for manager reference
        });

        // Create enrollment if class is specified for students
        debugPrint(
          'BulkImport: Checking enrollment - classId=$classId, role=${user['role']}, schoolId=$schoolId',
        );
        if (classId != null && user['role'] == 'student' && schoolId != null) {
          // Get current academic year
          final academicYearResp = await adminClient
              .from('academic_years')
              .select('id')
              .eq('school_id', schoolId)
              .eq('is_current', true)
              .maybeSingle();

          debugPrint('BulkImport: Academic year response: $academicYearResp');
          if (academicYearResp != null) {
            await adminClient.from('enrollments').insert({
              'user_id': newUserId,
              'class_id': classId,
              'academic_year_id': academicYearResp['id'],
              'is_active': true,
              'student_code': code,
            });
            debugPrint(
              'BulkImport: Enrollment created for $newUserId in class $classId',
            );
          } else {
            debugPrint(
              'BulkImport: No current academic year found for school $schoolId',
            );
          }
        } else {
          debugPrint(
            'BulkImport: Skipping enrollment - classId=$classId, role=${user['role']}, schoolId=$schoolId',
          );
        }

        _createdUsers.add({
          'fullName': user['fullName']!,
          'email': user['email']!,
          'password': password,
          'code': code,
          'className': className ?? '',
        });
        _successCount++;
      } catch (e) {
        _errors.add('${user['email']}: $e');
        _failCount++;
      }
    }

    setState(() {
      _isImporting = false;
      _parsedUsers = [];
      _status = 'Import terminé: $_successCount succès, $_failCount échec(s)';
    });
  }

  String _generatePassword({int length = 12}) {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789!@#\$%&*';
    final random = DateTime.now().microsecondsSinceEpoch;
    final buffer = StringBuffer();
    for (int i = 0; i < length; i++) {
      buffer.write(chars[(random * (i + 1) * 7 + i * 31) % chars.length]);
    }
    return buffer.toString();
  }

  Future<String> _generateCode(String role) async {
    final year = DateTime.now().year;
    final prefix = role == 'student' ? 'STU' : 'MGR';
    final countResp = await Supabase.instance.client
        .from('users')
        .select('id')
        .eq('role', role == 'student' ? 'student' : 'staff')
        .like('student_code', '$prefix-$year-%');
    final count = (countResp as List).length + 1;
    return '$prefix-$year-${count.toString().padLeft(4, '0')}';
  }

  Future<void> _downloadTemplate() async {
    final excel = Excel.createExcel();
    final sheet = excel['Utilisateurs'];

    // Headers
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue(
      'Nom complet *',
    );
    sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue('Email *');
    sheet.cell(CellIndex.indexByString('C1')).value = TextCellValue(
      'Téléphone',
    );
    sheet.cell(CellIndex.indexByString('D1')).value = TextCellValue('Rôle');
    sheet.cell(CellIndex.indexByString('E1')).value = TextCellValue(
      'Date naissance',
    );
    sheet.cell(CellIndex.indexByString('F1')).value = TextCellValue('Adresse');
    sheet.cell(CellIndex.indexByString('G1')).value = TextCellValue(
      'Genre (M/F)',
    );
    sheet.cell(CellIndex.indexByString('H1')).value = TextCellValue(
      'Nationalité',
    );
    sheet.cell(CellIndex.indexByString('I1')).value = TextCellValue('Niveau *');
    sheet.cell(CellIndex.indexByString('J1')).value = TextCellValue(
      'Classe (optionnel)',
    );

    // Get example class name from available classes
    String exampleClass1 = '';
    String exampleNiveau1 = '8eme';
    String exampleNiveau2 = '9eme';

    if (_availableClasses.isNotEmpty) {
      exampleClass1 = _availableClasses[0]['name'] ?? '';
      final niveauInfo1 =
          _availableClasses[0]['niveaux'] as Map<String, dynamic>?;
      if (niveauInfo1 != null) {
        exampleNiveau1 = niveauInfo1['code'] ?? '8eme';
      }
      if (_availableClasses.length > 1) {
        // exampleClass2 available if needed
        final niveauInfo2 =
            _availableClasses[1]['niveaux'] as Map<String, dynamic>?;
        if (niveauInfo2 != null) {
          exampleNiveau2 = niveauInfo2['code'] ?? '9eme';
        }
      }
    }

    // Row 1 - Example student with class specified
    sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue(
      'Ahmed Ben Ali',
    );
    sheet.cell(CellIndex.indexByString('B2')).value = TextCellValue(
      'ahmed.benali@example.com',
    );
    sheet.cell(CellIndex.indexByString('C2')).value = TextCellValue(
      '+216 55 123 456',
    );
    sheet.cell(CellIndex.indexByString('D2')).value = TextCellValue('student');
    sheet.cell(CellIndex.indexByString('E2')).value = TextCellValue(
      '15/03/2008',
    );
    sheet.cell(CellIndex.indexByString('F2')).value = TextCellValue(
      'Tunis, Tunisie',
    );
    sheet.cell(CellIndex.indexByString('G2')).value = TextCellValue('M');
    sheet.cell(CellIndex.indexByString('H2')).value = TextCellValue('Tunisien');
    sheet.cell(CellIndex.indexByString('I2')).value = TextCellValue(
      exampleNiveau1,
    );
    sheet.cell(CellIndex.indexByString('J2')).value = TextCellValue(
      exampleClass1,
    );

    // Row 2 - Example student without class (will be auto-assigned)
    sheet.cell(CellIndex.indexByString('A3')).value = TextCellValue(
      'Fatma Trabelsi',
    );
    sheet.cell(CellIndex.indexByString('B3')).value = TextCellValue(
      'fatma.trabelsi@example.com',
    );
    sheet.cell(CellIndex.indexByString('C3')).value = TextCellValue(
      '+216 22 987 654',
    );
    sheet.cell(CellIndex.indexByString('D3')).value = TextCellValue('student');
    sheet.cell(CellIndex.indexByString('E3')).value = TextCellValue(
      '22/07/2009',
    );
    sheet.cell(CellIndex.indexByString('F3')).value = TextCellValue(
      'Sfax, Tunisie',
    );
    sheet.cell(CellIndex.indexByString('G3')).value = TextCellValue('F');
    sheet.cell(CellIndex.indexByString('H3')).value = TextCellValue(
      'Tunisienne',
    );
    sheet.cell(CellIndex.indexByString('I3')).value = TextCellValue(
      exampleNiveau2,
    );
    // J3 left empty - class will be auto-assigned based on niveau

    // Add a sheet with available classes and niveaux for reference
    if (_availableClasses.isNotEmpty || _availableNiveaux.isNotEmpty) {
      final refSheet = excel['Niveaux et Classes'];
      refSheet.cell(CellIndex.indexByString('A1')).value = TextCellValue(
        'Code Niveau',
      );
      refSheet.cell(CellIndex.indexByString('B1')).value = TextCellValue(
        'Nom du Niveau',
      );
      refSheet.cell(CellIndex.indexByString('C1')).value = TextCellValue(
        'Nom de la Classe',
      );
      refSheet.cell(CellIndex.indexByString('D1')).value = TextCellValue(
        '(Utilisez le Code Niveau dans la colonne I)',
      );

      // List all classes with their niveau info
      for (var i = 0; i < _availableClasses.length; i++) {
        final row = i + 2;
        final c = _availableClasses[i];
        final niveauInfo = c['niveaux'] as Map<String, dynamic>?;

        refSheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
          niveauInfo?['code'] ?? '',
        );
        refSheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue(
          niveauInfo?['name'] ?? '',
        );
        refSheet.cell(CellIndex.indexByString('C$row')).value = TextCellValue(
          c['name'] ?? '',
        );
      }
    }

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final bytes = excel.encode();
    if (bytes != null) {
      await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer le modèle',
        fileName: 'modele_import_utilisateurs.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: Uint8List.fromList(bytes),
      );
    }
  }

  Future<void> _exportCredentials() async {
    if (_createdUsers.isEmpty) return;

    final excel = Excel.createExcel();
    final sheet = excel['Identifiants'];

    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue(
      'Nom complet',
    );
    sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue('Email');
    sheet.cell(CellIndex.indexByString('C1')).value = TextCellValue(
      'Mot de passe',
    );
    sheet.cell(CellIndex.indexByString('D1')).value = TextCellValue('Code');
    sheet.cell(CellIndex.indexByString('E1')).value = TextCellValue('Classe');

    for (var i = 0; i < _createdUsers.length; i++) {
      final row = i + 2;
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
        _createdUsers[i]['fullName'] ?? '',
      );
      sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue(
        _createdUsers[i]['email'] ?? '',
      );
      sheet.cell(CellIndex.indexByString('C$row')).value = TextCellValue(
        _createdUsers[i]['password'] ?? '',
      );
      sheet.cell(CellIndex.indexByString('D$row')).value = TextCellValue(
        _createdUsers[i]['code'] ?? '',
      );
      sheet.cell(CellIndex.indexByString('E$row')).value = TextCellValue(
        _createdUsers[i]['className'] ?? '',
      );
    }

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final bytes = excel.encode();
    if (bytes != null) {
      final timestamp = DateTime.now()
          .toString()
          .split('.')
          .first
          .replaceAll(':', '-');
      await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer les identifiants',
        fileName: 'identifiants_generes_$timestamp.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: Uint8List.fromList(bytes),
      );
    }
  }
}

// Custom painter for dashed border on the upload zone
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const dashWidth = 8.0;
    const dashSpace = 10.0;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(16),
    );
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}