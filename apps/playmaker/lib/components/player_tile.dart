import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:playmakerappstart/models/user_model.dart'; // Assuming PlayerProfile is here
import 'package:country_picker/country_picker.dart'; // For country flag emoji

enum PlayerTileActionType {
  none,
  acceptDecline,
  removeIcon,
  addIcon,
  checkbox,
  moreOptions,
  customWidget,
  statusText,
}

class PlayerTile extends StatelessWidget {
  final PlayerProfile playerProfile;
  final VoidCallback? onTap;
  final bool showPosition; // Will also act as showLevel for personalLevel
  final bool showPlayerId;
  final bool showCountryFlag;
  final bool showAge; // New parameter
  final bool isSelected;
  final bool isDisabled;

  final EdgeInsetsGeometry? contentPadding;
  final Color? tileColor;
  final Color? selectedTileColor;
  final Color? disabledTileColor;
  final ShapeBorder? customShape;

  final PlayerTileActionType actionType;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onRemove;
  final VoidCallback? onAdd;
  final VoidCallback? onMoreOptions;
  final Function(bool?)? onToggleSelection; // Changed to bool? for Checkbox
  final bool isCheckboxChecked;
  final Widget? customTrailingWidget;
  final String? statusText;
  final Color? statusTextColor;
  final IconData? singleActionIcon; // For removeIcon, addIcon
  final Color? singleActionIconColor;

  // Contextual display info
  final bool isHostContext; // e.g., for match details, to show "Host"
  final bool isCaptainContext; // e.g., for squad details, to show "Captain"
  final bool isGuest;
  final String? guestHostName;
  // final int? guestNumber; // If needed, can be displayed in subtitle or title

  const PlayerTile({
    super.key,
    required this.playerProfile,
    this.onTap,
    this.showPosition = true, 
    this.showPlayerId = false, 
    this.showCountryFlag = true,
    this.showAge = false, // Default changed to false
    this.isSelected = false,
    this.isDisabled = false,
    this.contentPadding,
    this.tileColor,
    this.selectedTileColor,
    this.disabledTileColor,
    this.customShape,
    this.actionType = PlayerTileActionType.none,
    this.onAccept,
    this.onDecline,
    this.onRemove,
    this.onAdd,
    this.onMoreOptions,
    this.onToggleSelection,
    this.isCheckboxChecked = false,
    this.customTrailingWidget,
    this.statusText,
    this.statusTextColor,
    this.singleActionIcon,
    this.singleActionIconColor,
    this.isHostContext = false,
    this.isCaptainContext = false,
    this.isGuest = false,
    this.guestHostName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandColor = const Color(0xFF00BF63); // Playmaker Green

    Color currentTileColor = tileColor ?? Colors.white;
    if (isDisabled) {
      currentTileColor = disabledTileColor ?? theme.disabledColor.withOpacity(0.05);
    } else if (isSelected) {
      currentTileColor = selectedTileColor ?? brandColor.withOpacity(0.1);
    }

    BorderSide borderSide = BorderSide(
      color: isDisabled 
          ? Colors.grey.shade300 
          : (isSelected ? brandColor : Colors.grey.shade200),
      width: isSelected ? 2 : 1,
    );

    final country = playerProfile.nationality.isNotEmpty 
        ? Country.tryParse(playerProfile.nationality) 
        : null;

    Widget? trailingWidget;
    switch (actionType) {
      case PlayerTileActionType.acceptDecline:
        trailingWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle_outline, color: Colors.green),
              onPressed: isDisabled ? null : onAccept,
              tooltip: 'Accept',
            ),
            IconButton(
              icon: const Icon(Icons.cancel_outlined, color: Colors.red),
              onPressed: isDisabled ? null : onDecline,
              tooltip: 'Decline',
            ),
          ],
        );
        break;
      case PlayerTileActionType.removeIcon:
        trailingWidget = IconButton(
          icon: Icon(singleActionIcon ?? Icons.delete_outline, color: singleActionIconColor ?? Colors.red),
          onPressed: isDisabled ? null : onRemove,
          tooltip: 'Remove',
        );
        break;
      case PlayerTileActionType.addIcon:
        trailingWidget = IconButton(
          icon: Icon(singleActionIcon ?? Icons.add_circle_outline, color: singleActionIconColor ?? brandColor),
          onPressed: isDisabled ? null : onAdd,
          tooltip: 'Add',
        );
        break;
      case PlayerTileActionType.checkbox:
        trailingWidget = Checkbox(
          value: isCheckboxChecked,
          onChanged: isDisabled ? null : onToggleSelection,
          activeColor: brandColor,
          side: isDisabled ? BorderSide(color: theme.disabledColor) : null,
        );
        break;
      case PlayerTileActionType.moreOptions:
        trailingWidget = IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: isDisabled ? null : onMoreOptions,
          tooltip: 'More options',
        );
        break;
      case PlayerTileActionType.customWidget:
        trailingWidget = customTrailingWidget;
        break;
      case PlayerTileActionType.statusText:
        trailingWidget = Padding(
          padding: const EdgeInsets.only(right: 8.0), // Ensure text isn't too close to edge
          child: Text(
            statusText ?? '',
            style: theme.textTheme.bodySmall?.copyWith(
              color: statusTextColor ?? theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        );
        break;
      case PlayerTileActionType.none:
        trailingWidget = null;
        break;
    }

    String titleText = playerProfile.name.isNotEmpty ? playerProfile.name : 'Unnamed Player';
    if (isHostContext) titleText += ' (Host)';
    if (isCaptainContext) titleText += ' (Captain)';
    
    String subtitleText = '';
    if (isGuest) {
      subtitleText = 'Guest of ${guestHostName ?? 'Unknown'}';
    } else {
      List<String> subtitleParts = [];
      if (showPosition) {
        if (playerProfile.preferredPosition.isNotEmpty) {
          subtitleParts.add(playerProfile.preferredPosition);
        }
        if (playerProfile.personalLevel.isNotEmpty) {
          subtitleParts.add(playerProfile.personalLevel);
        }
      }
      if (showAge && playerProfile.age.isNotEmpty) { // Still allow showing age if explicitly set
        subtitleParts.add('Age: ${playerProfile.age}');
      }
      if (showPlayerId && playerProfile.playerId != null && playerProfile.playerId!.isNotEmpty) {
        subtitleParts.add('ID: #${playerProfile.playerId}');
      }
      subtitleText = subtitleParts.join(' • ');
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 0.0), // Further reduced vertical margin
      elevation: 0,
      color: currentTileColor,
      shape: customShape ?? RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: borderSide,
      ),
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(12), // Match card's border radius
        splashColor: brandColor.withOpacity(0.1),
        highlightColor: brandColor.withOpacity(0.05),
        child: ListTile(
          leading: CircleAvatar(
            radius: 22,
            backgroundImage: playerProfile.profilePicture.isNotEmpty
                ? CachedNetworkImageProvider(playerProfile.profilePicture)
                : null,
            backgroundColor: brandColor.withOpacity(0.1),
            child: playerProfile.profilePicture.isEmpty
                ? Text(
                    playerProfile.name.isNotEmpty
                        ? playerProfile.name.substring(0, 1).toUpperCase()
                        : '?',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: brandColor,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          title: Row(
            children: [
              Flexible( // Use Flexible for the Text to allow it to take space but not overflow the Row
                child: Text(
                  titleText,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDisabled ? theme.disabledColor : theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showCountryFlag && country != null && !isGuest) ...[
                const SizedBox(width: 4), // Reduced space before flag
                Text(country.flagEmoji, style: const TextStyle(fontSize: 16)),
              ],
              // Player ID is handled in subtitle if showPlayerId is true
            ],
          ),
          subtitle: subtitleText.isNotEmpty
              ? Text(
                  subtitleText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDisabled 
                        ? theme.disabledColor 
                        : theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          trailing: trailingWidget,
        ),
      ),
    );
  }
}
