import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/chat_provider.dart';
import '../../services/chat_service.dart';
import '../../services/user_session_service.dart';
import '../../widgets/common/chat_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _lastMessageCount = 0;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _autoScrollIfNeeded(int messageCount) {
    if (messageCount <= _lastMessageCount) {
      return;
    }
    _lastMessageCount = messageCount;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final content = _controller.text.trim();
    if (content.isEmpty) {
      return;
    }

    try {
      await context.read<ChatProvider>().sendTextMessage(content);
      _controller.clear();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không gửi được tin nhắn: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _roomSubtitle(ChatRoomModel room, String currentUserId) {
    final others = room.participants
        .where((id) => id != currentUserId)
        .toList();
    if (others.isEmpty) {
      return 'Đơn #${room.orderId}';
    }
    return 'Đơn #${room.orderId} • ${others.join(', ')}';
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.watch<UserSessionService>().currentUserId;
    final chatProvider = context.watch<ChatProvider>();

    if (chatProvider.currentUserId != currentUserId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        context.read<ChatProvider>().setCurrentUser(currentUserId);
      });
    }

    _autoScrollIfNeeded(chatProvider.messages.length);

    return Scaffold(
      appBar: AppBar(title: const Text('Trò chuyện')),
      body: Column(
        children: [
          if (chatProvider.error != null)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.errorContainer,
              padding: const EdgeInsets.all(10),
              child: Text(
                chatProvider.error!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 280,
                  child: _RoomsPanel(
                    rooms: chatProvider.rooms,
                    selectedRoomId: chatProvider.selectedRoomId,
                    isLoading: chatProvider.roomsLoading,
                    currentUserId: currentUserId,
                    subtitleBuilder: _roomSubtitle,
                    onSelectRoom: (roomId) {
                      context.read<ChatProvider>().selectRoom(roomId);
                    },
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _MessagesPanel(
                    messages: chatProvider.messages,
                    selectedRoom: chatProvider.selectedRoom,
                    currentUserId: currentUserId,
                    isLoading: chatProvider.messagesLoading,
                    scrollController: _scrollController,
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: const InputDecoration(
                          hintText: 'Nhập tin nhắn...',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton.filled(
                      tooltip: 'Gửi',
                      onPressed: chatProvider.sending ? null : _sendMessage,
                      icon: chatProvider.sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomsPanel extends StatelessWidget {
  const _RoomsPanel({
    required this.rooms,
    required this.selectedRoomId,
    required this.isLoading,
    required this.currentUserId,
    required this.subtitleBuilder,
    required this.onSelectRoom,
  });

  final List<ChatRoomModel> rooms;
  final String? selectedRoomId;
  final bool isLoading;
  final String currentUserId;
  final String Function(ChatRoomModel room, String currentUserId)
  subtitleBuilder;
  final ValueChanged<String> onSelectRoom;

  @override
  Widget build(BuildContext context) {
    if (isLoading && rooms.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (rooms.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Chưa có phòng chat.\nPhòng sẽ được tạo khi có carrier nhận đơn.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: rooms.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final room = rooms[index];
        final isSelected = room.id == selectedRoomId;
        return ListTile(
          selected: isSelected,
          leading: const CircleAvatar(child: Icon(Icons.group_outlined)),
          title: Text('Room ${room.id}'),
          subtitle: Text(subtitleBuilder(room, currentUserId)),
          onTap: () => onSelectRoom(room.id),
        );
      },
    );
  }
}

class _MessagesPanel extends StatelessWidget {
  const _MessagesPanel({
    required this.messages,
    required this.selectedRoom,
    required this.currentUserId,
    required this.isLoading,
    required this.scrollController,
  });

  final List<ChatMessageModel> messages;
  final ChatRoomModel? selectedRoom;
  final String currentUserId;
  final bool isLoading;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (selectedRoom == null) {
      return const Center(child: Text('Chọn một cuộc trò chuyện để bắt đầu.'));
    }

    if (isLoading && messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (messages.isEmpty) {
      return const Center(child: Text('Chưa có tin nhắn.'));
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isMe = message.senderId == currentUserId;
        return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  message.senderId,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 4),
                ChatBubble(text: message.content, isMe: isMe),
              ],
            ),
          ),
        );
      },
    );
  }
}
