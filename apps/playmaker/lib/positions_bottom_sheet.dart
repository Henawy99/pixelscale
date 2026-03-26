import 'package:flutter/material.dart';
import 'package:playmakerappstart/localization/app_localizations.dart';

class PositionsBottomSheetModal extends StatelessWidget {
  final Function(String) onPositionSelected;
  final String currentPosition;

  const PositionsBottomSheetModal({
    Key? key,
    required this.onPositionSelected,
    required this.currentPosition,
  }) : super(key: key);

  List<Map<String, String>> _getLocalizedPositions(BuildContext context) {
    return [
      {
        'key': 'Goalkeeper (GK)', // Keep original key for matching currentPosition
        'title': context.loc.positionGoalkeeperTitle,
        'description': context.loc.positionGoalkeeperDescription,
        'icon': 'assets/images/goalkeeper.png'
      },
      {
        'key': 'Last Man Defender',
        'title': context.loc.positionLastManDefenderTitle,
        'description': context.loc.positionLastManDefenderDescription,
        'icon': 'assets/images/defender.png'
      },
      {
        'key': 'Winger',
        'title': context.loc.positionWingerTitle,
        'description': context.loc.positionWingerDescription,
        'icon': 'assets/images/winger.png'
      },
      {
        'key': 'Striker',
        'title': context.loc.positionStrikerTitle,
        'description': context.loc.positionStrikerDescription,
        'icon': 'assets/images/striker.png'
      },
      {
        'key': 'All Rounder',
        'title': context.loc.positionAllRounderTitle,
        'description': context.loc.positionAllRounderDescription,
        'icon': 'assets/images/allrounder.png'
      }
    ];
  }

  @override
  Widget build(BuildContext context) {
    final localizedPositions = _getLocalizedPositions(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          _buildTitle(context),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: localizedPositions.map((position) =>
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildPositionCard(context, position, localizedPositions),
                ),
              ).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(
            context.loc.chooseYourPositionTitle,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.loc.chooseYourPositionSubtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPositionCard(BuildContext context, Map<String, String> position, List<Map<String, String>> allPositions) {
    // Match based on the original English key to handle currentPosition correctly
    final originalTitleKey = allPositions.firstWhere((p) => p['title'] == position['title'], orElse: () => {'key': ''})['key'];
    final isSelected = originalTitleKey == currentPosition;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected 
            ? Theme.of(context).primaryColor
            : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
        color: isSelected 
          ? Theme.of(context).primaryColor.withOpacity(0.05)
          : Colors.white,
      ),
      child: InkWell(
        onTap: () {
          onPositionSelected(position['key']!); // Use the original key for saving
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildPositionIcon(position),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPositionInfo(position),
              ),
              _buildSelectionIndicator(context, isSelected),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPositionIcon(Map<String, String> position) {
    return Hero(
      tag: 'position_${position['key']}', // Use key for Hero tag
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade100,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            position['icon']!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey.shade200,
                child: Icon(
                  Icons.sports_soccer,
                  size: 30,
                  color: Colors.grey.shade400,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPositionInfo(Map<String, String> position) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          position['title']!,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          position['description']!,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionIndicator(BuildContext context, bool isSelected) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Icon(
        isSelected ? Icons.check_circle : Icons.arrow_forward_ios,
        color: isSelected 
          ? Theme.of(context).primaryColor
          : Colors.grey.shade400,
        size: isSelected ? 24 : 16,
      ),
    );
  }
}

// Usage example:
void showPositionsModal(BuildContext context, String currentPosition, Function(String) onPositionSelected) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => PositionsBottomSheetModal(
      currentPosition: currentPosition,
      onPositionSelected: onPositionSelected,
    ),
  );
}
