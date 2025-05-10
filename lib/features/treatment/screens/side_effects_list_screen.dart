// lib/features/treatment/screens/side_effects_list_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/side_effect.dart';
import '../../../core/storage/database_helper.dart';
import 'add_side_effect_screen.dart';

class SideEffectsListScreen extends StatefulWidget {
  final String entityType;
  final String entityId;
  final String entityName;

  const SideEffectsListScreen({
    Key? key,
    required this.entityType,
    required this.entityId,
    required this.entityName,
  }) : super(key: key);

  @override
  _SideEffectsListScreenState createState() => _SideEffectsListScreenState();
}

class _SideEffectsListScreenState extends State<SideEffectsListScreen> {
  List<SideEffect> _sideEffects = [];
  bool _isLoading = true;

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
      final maps = await dbHelper.getSideEffectsForEntity(
        widget.entityType,
        widget.entityId,
      );

      setState(() {
        _sideEffects = maps.map((map) => SideEffect.fromMap(map)).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des effets secondaires: $e');
      setState(() {
        _isLoading = false;
        _sideEffects = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Effets secondaires'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _sideEffects.isEmpty
              ? _buildEmptyState()
              : _buildSideEffectsList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddSideEffectScreen(
                entityType: widget.entityType,
                entityId: widget.entityId,
                entityName: widget.entityName,
              ),
            ),
          );
          
          if (result == true) {
            _loadSideEffects();
          }
        },
        child: Icon(Icons.add),
        tooltip: 'Ajouter un effet secondaire',
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.healing,
            size: 80,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'Aucun effet secondaire',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Ajoutez un effet secondaire en cliquant sur le bouton +',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildSideEffectsList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _sideEffects.length,
      itemBuilder: (context, index) {
        final sideEffect = _sideEffects[index];
        return Card(
          margin: EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('dd/MM/yyyy').format(sideEffect.date),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    _buildSeverityBadge(sideEffect.severity),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  sideEffect.description,
                  style: TextStyle(fontSize: 16),
                ),
                if (sideEffect.notes != null && sideEffect.notes!.isNotEmpty) ...[
                  SizedBox(height: 8),
                  Text(
                    'Notes:',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    sideEffect.notes!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        _showDeleteConfirmation(context, sideEffect);
                      },
                      child: Text('Supprimer'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                    SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        // Navigation vers l'écran d'édition (à implémenter)
                      },
                      child: Text('Modifier'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSeverityBadge(SideEffectSeverity severity) {
    Color color;
    String text;

    switch (severity) {
      case SideEffectSeverity.Minor:
        color = Colors.green;
        text = 'Mineur';
        break;
      case SideEffectSeverity.Moderate:
        color = Colors.blue;
        text = 'Modéré';
        break;
      case SideEffectSeverity.Serious:
        color = Colors.orange;
        text = 'Sérieux';
        break;
      case SideEffectSeverity.Severe:
        color = Colors.deepOrange;
        text = 'Sévère';
        break;
      case SideEffectSeverity.Critical:
        color = Colors.red;
        text = 'Critique';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, SideEffect sideEffect) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer cet effet secondaire?'),
        content: Text(
          'Cette action est irréversible. Voulez-vous vraiment supprimer cet effet secondaire?'
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              try {
                final dbHelper = DatabaseHelper();
                await dbHelper.deleteSideEffect(sideEffect.id);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Effet secondaire supprimé')),
                );
                
                _loadSideEffects();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur lors de la suppression: $e')),
                );
              }
            },
            child: Text('Supprimer'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}
