import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Combine and sort messages by index
  List<Map<String, dynamic>> _getSortedMessages(AppProvider provider) {
    List<Map<String, dynamic>> messages = [];
    for (var message in provider.inboxBucket) {
      try {
        final parts = message.split(':');
        if (parts.length < 2) continue;
        final index = int.parse(parts[0]);
        messages.add({
          'index': index,
          'text': message.substring(message.indexOf(':') + 1),
          'isInbox': true,
        });
      } catch (e) {
        print('Invalid inbox message format: $message');
      }
    }
    for (var message in provider.sentboxBucket) {
      try {
        final parts = message.split(':');
        if (parts.length < 2) continue;
        final index = int.parse(parts[0]);
        messages.add({
          'index': index,
          'text': message.substring(message.indexOf(':') + 1),
          'isInbox': false,
        });
      } catch (e) {
        print('Invalid sentbox message format: $message');
      }
    }
    messages.sort((a, b) => a['index'].compareTo(b['index']));
    return messages;
  }

  Future<void> _sendMessage(AppProvider provider) async {
    if (_controller.text.isEmpty) return;
    final success = await provider.sendMessage(_controller.text);
    if (success) {
      _controller.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message sent')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final messages = _getSortedMessages(provider);

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return Align(
                  alignment: message['isInbox'] ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    padding: const EdgeInsets.all(10),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.6,
                    ),
                    decoration: BoxDecoration(
                      color: message['isInbox'] ? Colors.grey[300] : Colors.blue[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      message['text'],
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _sendMessage(provider),
                  child: const Text('Send'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}