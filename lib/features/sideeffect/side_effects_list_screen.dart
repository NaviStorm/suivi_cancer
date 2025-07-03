import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:suivi_cancer/utils/logger.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/features/treatment/models/side_effect.dart';
import 'package:suivi_cancer/features/sideeffect/side_effects_list.dart';
import 'package:suivi_cancer/features/sideeffect/add_side_effect_screen.dart';
import 'package:suivi_cancer/core/widgets/common/universal_snack_bar.dart';

class SideEffectsListScreen extends StatefulWidget {
  final String entityType;
  final String entityId;
  final String entityName;

  const SideEffectsListScreen({
    super.key,
    required this.entityType,
    required this.entityId,
    required this.entityName,
  });

  @override
  _SideEffectsListScreenState createState() => _SideEffectsListScreenState();
}

class _SideEffectsListScreenState extends State<SideEffectsListScreen> {
  List<SideEffect> _sideEffects = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSideEffects();
  }

  Future<void> _loadSideEffects() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbHelper = DatabaseHelper();
      final sideEffectMaps = await dbHelper.getSideEffectsByEntity(
        widget.entityType,
        widget.entityId,
      );

      setState(() {
        _sideEffects =
            sideEffectMaps.map((map) => SideEffect.fromMap(map)).toList();
        _isLoading = false;
      });
    } catch (e) {
      Log.d("Erreur lors du chargement des effets secondaires: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addSideEffect() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => AddSideEffectScreen(
              entityType: widget.entityType,
              entityId: widget.entityId,
              entityName: widget.entityName,
            ),
      ),
    );

    if (result == true) {
      _loadSideEffects();
    }
  }

  void _editSideEffect(SideEffect sideEffect) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => AddSideEffectScreen(
              entityType: widget.entityType,
              entityId: widget.entityId,
              entityName: widget.entityName,
              sideEffect: sideEffect, // Passer l'effet secondaire à modifier
            ),
      ),
    );

    if (result == true) {
      _loadSideEffects();
    }
  }

  void _deleteSideEffect(SideEffect sideEffect) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Supprimer l\'effet secondaire'),
            content: Text(
              'Êtes-vous sûr de vouloir supprimer cet effet secondaire ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Supprimer', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        final dbHelper = DatabaseHelper();
        await dbHelper.deleteSideEffect(sideEffect.id);

        UniversalSnackBar.show(context, title: 'Effet secondaire supprimé');

        _loadSideEffects();
      } catch (e) {
        Log.d("Erreur lors de la suppression: $e");
        UniversalSnackBar.show(context, title: 'Erreur lors de la suppression');
      }
    }
  }

  void _viewSideEffect(SideEffect sideEffect) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => Container(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Détails de l\'effet secondaire',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                Text(
                  'Description',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(sideEffect.description),
                SizedBox(height: 8),
                Text('Sévérité', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(_getSeverityText(sideEffect.severity)),
                SizedBox(height: 8),
                Text('Date', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(DateFormat('dd/MM/yyyy').format(sideEffect.date)),
                if (sideEffect.notes != null &&
                    sideEffect.notes!.isNotEmpty) ...[
                  SizedBox(height: 8),
                  Text('Notes', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(sideEffect.notes!),
                ],
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Fermer'),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  String _getSeverityText(SideEffectSeverity severity) {
    switch (severity) {
      case SideEffectSeverity.Minor:
        return 'Mineur';
      case SideEffectSeverity.Moderate:
        return 'Modéré';
      case SideEffectSeverity.Serious:
        return 'Sérieux';
      case SideEffectSeverity.Severe:
        return 'Sévère';
      case SideEffectSeverity.Critical:
        return 'Critique';
      default:
        return 'Inconnu';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Effets secondaires')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête avec le nom de l'entité
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              widget.entityName,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadSideEffects,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: SideEffectsList(
                  entityType: widget.entityType,
                  entityId: widget.entityId,
                  sideEffects: _sideEffects,
                  isLoading: _isLoading,
                  onRefresh: _loadSideEffects,
                  onEdit: _editSideEffect,
                  onDelete: _deleteSideEffect,
                  onView: _viewSideEffect,
                  onAdd: _addSideEffect,
                  showTitle: false,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSideEffect,
        tooltip: 'Ajouter un effet secondaire',
        child: Icon(Icons.add),
      ),
    );
  }
}
