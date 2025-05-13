import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:suivi_cancer/features/treatment/models/side_effect.dart';
import 'package:suivi_cancer/utils/logger.dart';

class SideEffectsList extends StatelessWidget {
  final String entityType;
  final String entityId;
  final List<SideEffect> sideEffects;
  final bool isLoading;
  final Function() onRefresh;
  final Function(SideEffect) onEdit;
  final Function(SideEffect) onDelete;
  final Function(SideEffect) onView;
  final Function() onAdd;
  final bool showTitle;

  const SideEffectsList({
    Key? key,
    required this.entityType,
    required this.entityId,
    required this.sideEffects,
    required this.isLoading,
    required this.onRefresh,
    required this.onEdit,
    required this.onDelete,
    required this.onView,
    required this.onAdd,
    this.showTitle = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Log.d('SideEffectsList');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Effets secondaires',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  icon: Icon(Icons.add, size: 16),
                  label: Text('Ajouter'),
                  onPressed: onAdd,
                ),
              ],
            ),
          ),
        
        if (isLoading)
          Center(child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ))
        else if (sideEffects.isEmpty)
          Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Text(
                'Aucun effet secondaire enregistré',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: sideEffects.length,
            itemBuilder: (context, index) {
              final sideEffect = sideEffects[index];
              return _buildSideEffectItem(context, sideEffect);
            },
          ),
      ],
    );
  }

//  return Card(
//  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
//  child: InkWell(
//  onTap: () => onView(sideEffect),

  Widget _buildSideEffectItem(BuildContext context, SideEffect sideEffect) {
    // Couleur basée sur la sévérité
    Color severityColor;
    switch (sideEffect.severity) {
      case SideEffectSeverity.Minor:
        severityColor = Colors.green;
        break;
      case SideEffectSeverity.Moderate:
        severityColor = Colors.orange;
        break;
      case SideEffectSeverity.Serious:
        severityColor = Colors.deepOrange;
        break;
      case SideEffectSeverity.Severe:
        severityColor = Colors.red;
        break;
      case SideEffectSeverity.Critical:
        severityColor = Colors.purple;
        break;
      default:
        severityColor = Colors.grey;
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => onView(sideEffect),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Partie gauche : sévérité et date
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: severityColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: severityColor.withOpacity(0.5)),
                        ),
                        child: Text(
                          _getSeverityLabel(sideEffect.severity),
                          style: TextStyle(
                            color: severityColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        DateFormat('dd/MM/yyyy').format(sideEffect.date),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                  // Partie droite : boutons d'édition et de suppression
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                        onPressed: () => onEdit(sideEffect),
                        tooltip: 'Modifier',
                      ),
                      SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.delete, size: 20, color: Colors.red),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                        onPressed: () => onDelete(sideEffect),
                        tooltip: 'Supprimer',
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                sideEffect.description,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (sideEffect.notes != null && sideEffect.notes!.isNotEmpty) ...[
                SizedBox(height: 8),
                Text(
                  sideEffect.notes!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getSeverityLabel(SideEffectSeverity severity) {
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
}

