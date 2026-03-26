import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:playmakerappstart/models/user_model.dart';
import 'package:playmakerappstart/player_details_screen.dart';
import 'package:playmakerappstart/services/supabase_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MatchChatWidget extends StatefulWidget {
  final String bookingId;
  final String currentUserId;
  final String currentUserName;
  final PlayerProfile currentUserProfile;
  final bool isParticipant;

  const MatchChatWidget({
    super.key,
    required this.bookingId,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserProfile,
    required this.isParticipant,
  });

  @override
  State<MatchChatWidget> createState() => _MatchChatWidgetState();
}

class _MatchChatWidgetState extends State<MatchChatWidget>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SupabaseService _supabaseService = SupabaseService();
  final FocusNode _textFieldFocus = FocusNode();
  
  bool _isSending = false;
  bool _isTyping = false;
  late AnimationController _typingAnimationController;
  
  // Cached messages to show during connection issues
  List<Map<String, dynamic>>? _cachedMessages;

  @override
  void initState() {
    super.initState();
    _typingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Auto-scroll to bottom when keyboard appears
    _textFieldFocus.addListener(() {
      if (_textFieldFocus.hasFocus) {
        _scrollToBottom(delay: 500);
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _textFieldFocus.dispose();
    _typingAnimationController.dispose();
    super.dispose();
  }

  void _handleTyping(String value) {
    final bool newTypingState = value.trim().isNotEmpty;
    if (newTypingState != _isTyping) {
      setState(() {
        _isTyping = newTypingState;
      });
      
      if (_isTyping) {
        _typingAnimationController.forward();
      } else {
        _typingAnimationController.reverse();
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || !widget.isParticipant || _isSending) {
      return;
    }

    final messageText = _messageController.text.trim();
    setState(() {
      _isSending = true;
      _isTyping = false;
    });
    
    _messageController.clear();
    _typingAnimationController.reverse();
    _textFieldFocus.unfocus();

    try {
      await _supabaseService.sendChatMessage(
        widget.bookingId,
        widget.currentUserId,
        widget.currentUserName,
        messageText,
        widget.currentUserProfile.profilePicture,
      );
      
      _scrollToBottom();
    } catch (e) {
      _handleError('Failed to send message', e);
      // Restore the message on error
      _messageController.text = messageText;
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _handleError(String message, dynamic error) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$message: ${error.toString()}',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _scrollToBottom({int delay = 100}) {
    if (!mounted) return;
    
    Future.delayed(Duration(milliseconds: delay), () {
      if (_scrollController.hasClients && mounted) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildChatHeader(theme),
          Expanded(child: _buildChatMessages(theme)),
          if (widget.isParticipant)
            _buildMessageInput(theme)
          else
            _buildReadOnlyIndicator(theme),
        ],
      ),
    );
  }

  Widget _buildChatHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00BF63).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              color: Color(0xFF00BF63),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Match Chat',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  widget.isParticipant 
                    ? 'Share thoughts with your teammates'
                    : 'View match conversation',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (widget.isParticipant)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF00BF63).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Participant',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF00BF63),
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChatMessages(ThemeData theme) {
    // For demo bookings, show empty chat state
    if (widget.bookingId.startsWith('demo_')) {
      return _buildEmptyState();
    }
    
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabaseService.streamChatMessages(widget.bookingId),
      builder: (context, snapshot) {
        // Handle connection errors gracefully
        if (snapshot.hasError) {
          print('⚠️ Chat stream error: ${snapshot.error}');
          
          // If we have cached messages, show them with a subtle error indicator
          if (_cachedMessages != null && _cachedMessages!.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Connection issue, reconnecting...'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            });
            return _buildMessagesList(_cachedMessages!, showConnectionIssue: true);
          }
          
          // Only show full error state if we have no cached data
          return _buildErrorState(snapshot.error.toString());
        }
        
        if (snapshot.connectionState == ConnectionState.waiting && _cachedMessages == null) {
          return _buildLoadingState();
        }
        
        // Update cached messages when we get new data
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          _cachedMessages = snapshot.data;
        }
        
        final messages = snapshot.data ?? _cachedMessages;
        
        if (messages == null || messages.isEmpty) {
          return _buildEmptyState();
        }

        return _buildMessagesList(messages);
      },
    );
  }

  Widget _buildMessagesList(List<Map<String, dynamic>> messages, {bool showConnectionIssue = false}) {
    // Auto-scroll to bottom when new messages arrive
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Stack(
      children: [
        ListView.separated(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          itemCount: messages.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final messageData = messages[index];
            final isMe = messageData['sender_id'] == widget.currentUserId;
            
            return ChatMessageTile(
              message: messageData['message'] ?? '[empty message]',
              senderName: messageData['sender_name'] ?? '[unknown sender]',
              timestamp: messageData['created_at'] as String?,
              isMe: isMe,
              senderId: messageData['sender_id'] as String? ?? '',
              senderAvatarUrl: messageData['profile_picture'] as String?,
              currentUserProfile: widget.currentUserProfile,
              showDate: _shouldShowDate(messages, index),
            );
          },
        ),
        if (showConnectionIssue)
          Positioned(
            top: 8,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Reconnecting...',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  bool _shouldShowDate(List<Map<String, dynamic>> messages, int index) {
    if (index == 0) return true;
    
    final currentMessage = messages[index];
    final previousMessage = messages[index - 1];
    
    final currentTimestamp = currentMessage['created_at'] as String?;
    final previousTimestamp = previousMessage['created_at'] as String?;
    
    if (currentTimestamp == null || previousTimestamp == null) return false;
    
    final currentDate = DateTime.parse(currentTimestamp);
    final previousDate = DateTime.parse(previousTimestamp);
    
    return !_isSameDay(currentDate, previousDate);
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && 
           date1.month == date2.month && 
           date1.day == date2.day;
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00BF63)),
          ),
          SizedBox(height: 16),
          Text(
            'Loading messages...',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load chat',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF00BF63).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 40,
                color: Color(0xFF00BF63),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No messages yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.isParticipant
                ? 'Be the first to start the conversation!'
                : 'Messages will appear here when players chat',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput(ThemeData theme) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16, 
        12, 
        16, 
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _textFieldFocus.hasFocus 
                    ? const Color(0xFF00BF63)
                    : Colors.transparent,
                  width: 2,
                ),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _textFieldFocus,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20, 
                    vertical: 12,
                  ),
                ),
                minLines: 1,
                maxLines: 4,
                onChanged: _handleTyping,
                onSubmitted: (_) => _sendMessage(),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 48,
            width: 48,
            child: Material(
              color: _isTyping || _isSending
                ? const Color(0xFF00BF63)
                : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                onTap: (_isTyping || _isSending) ? _sendMessage : null,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: _isSending
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.send_rounded,
                        color: _isTyping ? Colors.white : Colors.grey.shade600,
                        size: 20,
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyIndicator(ThemeData theme) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20, 
        16, 
        20, 
        16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer.withOpacity(0.5),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.visibility_outlined,
            color: Colors.grey.shade600,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Only match participants can send messages',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessageTile extends StatelessWidget {
  final String message;
  final String senderName;
  final String? timestamp;
  final bool isMe;
  final String senderId;
  final String? senderAvatarUrl;
  final PlayerProfile currentUserProfile;
  final bool showDate;

  const ChatMessageTile({
    super.key,
    required this.message,
    required this.senderName,
    required this.timestamp,
    required this.isMe,
    required this.senderId,
    required this.senderAvatarUrl,
    required this.currentUserProfile,
    this.showDate = false,
  });

  Future<void> _navigateToPlayerDetails(BuildContext context) async {
    if (senderId.isEmpty) return;

    PlayerProfile? senderProfile;
    if (senderId == currentUserProfile.id) {
      senderProfile = currentUserProfile;
    } else {
      senderProfile = await SupabaseService().getUserProfileById(senderId);
    }

    if (senderProfile != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlayerDetailsScreen(
            player: senderProfile!,
            currentUserProfile: currentUserProfile,
          ),
        ),
      );
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      return DateFormat('h:mm a').format(dateTime);
    } else if (difference.inDays == 1) {
      return 'Yesterday ${DateFormat('h:mm a').format(dateTime)}';
    } else if (difference.inDays < 7) {
      return DateFormat('EEE h:mm a').format(dateTime);
    } else {
      return DateFormat('MMM d, h:mm a').format(dateTime);
    }
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE').format(dateTime);
    } else {
      return DateFormat('MMMM d, y').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final messageTime = timestamp != null ? DateTime.parse(timestamp!) : null;
    
    return Column(
      children: [
        // Date separator
        if (showDate && messageTime != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Expanded(child: Divider(color: Colors.grey.shade300)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _formatDate(messageTime),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey.shade300)),
              ],
            ),
          ),
        
        // Message content
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isMe) ...[
              _buildAvatar(context),
              const SizedBox(width: 12),
            ],
            
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                child: Column(
                  crossAxisAlignment: isMe 
                    ? CrossAxisAlignment.end 
                    : CrossAxisAlignment.start,
                  children: [
                    // Sender name and timestamp
                    Padding(
                      padding: EdgeInsets.only(
                        left: isMe ? 0 : 4,
                        right: isMe ? 4 : 0,
                        bottom: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: isMe 
                          ? MainAxisAlignment.end 
                          : MainAxisAlignment.start,
                        children: [
                          if (!isMe) ...[
                            Text(
                              senderName,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: const Color(0xFF00BF63),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (messageTime != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                _formatTime(messageTime),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ] else ...[
                            if (messageTime != null) ...[
                              Text(
                                _formatTime(messageTime),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              'You',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: const Color(0xFF00BF63),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    // Message bubble
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16, 
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isMe 
                          ? const Color(0xFF00BF63)
                          : theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: isMe 
                            ? const Radius.circular(20) 
                            : const Radius.circular(6),
                          bottomRight: isMe 
                            ? const Radius.circular(6) 
                            : const Radius.circular(20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        message,
                        style: TextStyle(
                          color: isMe ? Colors.white : theme.colorScheme.onSurface,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            if (isMe) ...[
              const SizedBox(width: 12),
              _buildAvatar(context),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildAvatar(BuildContext context) {
    return GestureDetector(
      onTap: () => _navigateToPlayerDetails(context),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF00BF63).withOpacity(0.2),
            width: 2,
          ),
        ),
        child: CircleAvatar(
          radius: 16,
          backgroundColor: const Color(0xFF00BF63).withOpacity(0.1),
          backgroundImage: senderAvatarUrl != null && senderAvatarUrl!.isNotEmpty
            ? CachedNetworkImageProvider(senderAvatarUrl!)
            : null,
          child: senderAvatarUrl == null || senderAvatarUrl!.isEmpty
            ? Text(
                senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Color(0xFF00BF63),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              )
            : null,
        ),
      ),
    );
  }
} 