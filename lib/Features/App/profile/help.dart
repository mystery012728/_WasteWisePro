import 'package:flutter/material.dart';
import 'package:flutternew/Features/App/User_auth/util/smack_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HelpPage extends StatefulWidget {
  const HelpPage({Key? key}) : super(key: key);

  @override
  _HelpPageState createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  final TextEditingController _chatController = TextEditingController();
  final TextEditingController _complaintController = TextEditingController();
  final TextEditingController _feedbackController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> chatMessages = [];
  int _selectedRating = 0;

  final List<Map<String, String>> _faqs = [
    {
      'question': 'How do I schedule a pickup?',
      'answer':
      'You can schedule a pickup by going to the home screen and clicking on the "Schedule Pickup" button. Follow the prompts to select your preferred date and time.',
    },
    {
      'question': 'What items can I recycle?',
      'answer':
      'We accept various recyclable items including paper, cardboard, plastic bottles, metal cans, and glass containers. Make sure all items are clean and dry before recycling.',
    },
    {
      'question': 'How do I track my pickup?',
      'answer':
      'You can track your pickup in real-time through the "Orders" section in your profile. You\'ll receive notifications about the status of your pickup.',
    },
  ];

  // Add new variables for chatbot functionality
  final List<String> _keywords = [
    'pickup',
    'schedule',
    'collect',
    'recycle',
    'waste',
    'garbage',
    'subscription',
    'payment',
    'price',
    'complaint',
    'problem',
    'issue',
    'feedback',
    'rating',
    'review',
    'contact',
    'help',
    'support',
    'track',
    'status',
    'location',
    'cancel',
    'refund',
    'return'
  ];

  @override
  void dispose() {
    _chatController.dispose();
    _complaintController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _saveChatMessage(String message, bool isBot) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    await _firestore.collection('chat_history').add({
      'userId': userId,
      'message': message,
      'isBot': isBot,
      'timestamp': FieldValue.serverTimestamp(),
    });

    setState(() {
      chatMessages.add({
        'message': message,
        'isBot': isBot,
      });
    });
  }

  Future<void> _submitComplaint() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Submit Complaint',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _complaintController,
          decoration: InputDecoration(
            hintText: 'Describe your complaint...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_complaintController.text.trim().isNotEmpty) {
                await _firestore.collection('user_complaints').add({
                  'userId': userId,
                  'complaint': _complaintController.text.trim(),
                  'status': 'pending',
                  'timestamp': FieldValue.serverTimestamp(),
                });
                _complaintController.clear();
                Navigator.pop(context);
                CustomSnackbar.showSuccess(
                  context: context,
                  message: 'Complaint submitted successfully',
                );
              }
            },
            child: Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitFeedback() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    // Reset rating when opening dialog
    setState(() {
      _selectedRating = 0;
    });

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Submit Feedback',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('How would you rate our service?',
                  style: GoogleFonts.poppins()),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                      (index) => IconButton(
                    icon: Icon(
                      Icons.star,
                      color:
                      index < _selectedRating ? Colors.amber : Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedRating = index + 1;
                      });
                    },
                  ),
                ),
              ),
              Text(
                _getRatingText(_selectedRating),
                style: GoogleFonts.poppins(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _feedbackController,
                decoration: InputDecoration(
                  hintText: 'Your feedback...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _selectedRating = 0;
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_selectedRating == 0) {
                  CustomSnackbar.showError(
                    context: context,
                    message: 'Please select a rating',
                  );
                  return;
                }
                if (_feedbackController.text.trim().isEmpty) {
                  CustomSnackbar.showError(
                    context: context,
                    message: 'Please provide feedback',
                  );
                  return;
                }

                await _firestore.collection('user_feedback').add({
                  'userId': userId,
                  'feedback': _feedbackController.text.trim(),
                  'rating': _selectedRating,
                  'timestamp': FieldValue.serverTimestamp(),
                  'userName': _auth.currentUser?.displayName ?? 'Anonymous',
                  'userEmail': _auth.currentUser?.email,
                  'ratingText': _getRatingText(_selectedRating),
                });

                // Store in user's feedback history
                await _firestore
                    .collection('user_details')
                    .doc(userId)
                    .collection('feedback_history')
                    .add({
                  'feedback': _feedbackController.text.trim(),
                  'rating': _selectedRating,
                  'timestamp': FieldValue.serverTimestamp(),
                  'ratingText': _getRatingText(_selectedRating),
                });

                _feedbackController.clear();
                _selectedRating = 0;
                Navigator.pop(context);
                CustomSnackbar.showSuccess(
                  context: context,
                  message: 'Thank you for your feedback!',
                );
              },
              child: Text('Submit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Very Dissatisfied';
      case 2:
        return 'Dissatisfied';
      case 3:
        return 'Neutral';
      case 4:
        return 'Satisfied';
      case 5:
        return 'Very Satisfied';
      default:
        return 'Select your rating';
    }
  }

  Future<void> _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'mystery12728@gmail.com',
      queryParameters: {
        'subject': 'Support Request',
      },
    );

    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    }
  }

  Future<void> _launchPhone() async {
    final Uri phoneLaunchUri = Uri(
      scheme: 'tel',
      path: '+919167415756',
    );

    if (await canLaunchUrl(phoneLaunchUri)) {
      await launchUrl(phoneLaunchUri);
    }
  }

  String _getBotResponse(String userMessage) {
    final lowercaseMessage = userMessage.toLowerCase();

    // First, check for greetings
    if (lowercaseMessage.contains('hi') ||
        lowercaseMessage.contains('hello') ||
        lowercaseMessage.contains('hey')) {
      return "Hello! I'm your recycling assistant. How can I help you today?";
    }

    // Check for thank you messages
    if (lowercaseMessage.contains('thank') ||
        lowercaseMessage.contains('thanks')) {
      return "You're welcome! Is there anything else I can help you with?";
    }

    // Check for goodbyes
    if (lowercaseMessage.contains('bye') ||
        lowercaseMessage.contains('goodbye')) {
      return "Goodbye! Feel free to come back if you need any more assistance.";
    }

    // Process the message for relevant keywords and context
    List<String> relevantResponses = [];

    // Check for complaints
    if (lowercaseMessage.contains('complaint') ||
        lowercaseMessage.contains('problem') ||
        lowercaseMessage.contains('issue') ||
        lowercaseMessage.contains('not working')) {
      relevantResponses.add(
          "I understand you're having an issue. I can help you submit a formal complaint or try to resolve it right here. Could you please provide more details about the problem?");
    }

    // Check for pickup related queries
    if (lowercaseMessage.contains('pickup') ||
        lowercaseMessage.contains('schedule') ||
        lowercaseMessage.contains('collect')) {
      relevantResponses.add(
          "For pickups, I can help you with scheduling, tracking, or answering any specific questions. What would you like to know about our pickup service?");
    }

    // Check for recycling queries
    if (lowercaseMessage.contains('recycle') ||
        lowercaseMessage.contains('waste') ||
        lowercaseMessage.contains('garbage')) {
      relevantResponses.add(
          "I can provide information about recyclable items, waste segregation, or our recycling process. What specific information are you looking for?");
    }

    // Check for subscription queries
    if (lowercaseMessage.contains('subscription') ||
        lowercaseMessage.contains('payment') ||
        lowercaseMessage.contains('price') ||
        lowercaseMessage.contains('cost')) {
      relevantResponses.add(
          "I can help you understand our subscription plans, pricing, payment methods, or any other billing-related questions. What would you like to know?");
    }

    // Check for tracking queries
    if (lowercaseMessage.contains('track') ||
        lowercaseMessage.contains('status') ||
        lowercaseMessage.contains('location')) {
      relevantResponses.add(
          "I can help you track your pickup or check its status. Would you like me to help you with that?");
    }

    // If no specific keywords were matched, provide a contextual response
    if (relevantResponses.isEmpty) {
      return "I'm here to help with anything related to our recycling services, including:\n"
          "- Pickup scheduling and tracking\n"
          "- Recycling guidelines and waste management\n"
          "- Subscription plans and payments\n"
          "- Technical support and troubleshooting\n"
          "- Complaints and feedback\n\n"
          "Please let me know what you'd like to know more about, and I'll be happy to assist!";
    }

    // If multiple relevant responses were found, combine them
    if (relevantResponses.length > 1) {
      return "I noticed a few things in your message. Let me address them:\n\n" +
          relevantResponses.join("\n\n");
    }

    return relevantResponses.first;
  }

  Future<void> _handleUserMessage(String message) async {
    if (message.trim().isEmpty) return;

    // Save user message
    await _saveChatMessage(message, false);
    _chatController.clear();

    // Analyze message and get appropriate response
    String botResponse = _getBotResponse(message);

    // Add slight delay to simulate processing
    await Future.delayed(Duration(milliseconds: 500));

    // Save bot response
    await _saveChatMessage(botResponse, true);

    // If message contains complaint-related keywords, suggest complaint form
    if (message.toLowerCase().contains('complaint') ||
        message.toLowerCase().contains('problem') ||
        message.toLowerCase().contains('issue')) {
      await Future.delayed(Duration(seconds: 1));
      await _saveChatMessage(
          "Would you like to submit a formal complaint? Click the 'Submit Complaint' button in the support options below.",
          true);
    }
  }

  void _openChatbot() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async {
          final shouldExit = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                'Exit Chat',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              ),
              content: Text(
                'Are you sure you want to exit the chat? A new chat session will be started next time.',
                style: GoogleFonts.poppins(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Stay'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade800,
                  ),
                  child: Text('Exit'),
                ),
              ],
            ),
          );
          return shouldExit ?? false;
        },
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Customer Support',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () async {
                        final shouldExit = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(
                              'Exit Chat',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                            content: Text(
                              'Are you sure you want to exit the chat? A new chat session will be started next time.',
                              style: GoogleFonts.poppins(),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: Text('Stay'),
                              ),
                              ElevatedButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade800,
                                ),
                                child: Text('Exit'),
                              ),
                            ],
                          ),
                        );
                        if (shouldExit ?? false) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('chat_history')
                          .where('userId', isEqualTo: _auth.currentUser?.uid)
                          .orderBy('timestamp', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Center(child: CircularProgressIndicator());
                        }

                        final messages = snapshot.data!.docs;
                        if (messages.isEmpty) {
                          // Send welcome message if no messages exist
                          Future.delayed(Duration.zero, () async {
                            await _saveChatMessage(
                                "Hello! 👋 I'm your recycling assistant. I'm here to help you with anything related to our services!\n\n"
                                    "You can ask me about:\n"
                                    "🚛 Scheduling and tracking pickups\n"
                                    "♻️ Recycling guidelines\n"
                                    "💳 Subscription plans and payments\n"
                                    "🔧 Technical support\n"
                                    "📝 Complaints and feedback\n\n"
                                    "How can I assist you today?",
                                true);
                          });
                        }

                        return ListView.builder(
                          reverse: true,
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message =
                            messages[index].data() as Map<String, dynamic>;
                            return _buildChatMessage(
                              message['message'],
                              isBot: message['isBot'],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _chatController,
                  decoration: InputDecoration(
                    hintText: 'Type your message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.send, color: Colors.green.shade800),
                      onPressed: () => _handleUserMessage(_chatController.text),
                    ),
                  ),
                  onSubmitted: _handleUserMessage,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatMessage(String message, {bool isBot = false}) {
    return Container(
      margin: EdgeInsets.only(
        left: isBot ? 0 : 40,
        right: isBot ? 40 : 0,
        bottom: 8,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isBot ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        message,
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final messages = await _firestore
        .collection('chat_history')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .get();

    setState(() {
      chatMessages = messages.docs
          .map((doc) => {
        'message': doc.data()['message'],
        'isBot': doc.data()['isBot'],
      })
          .toList();
    });
  }

  Widget _buildFAQItem(Map<String, String> faq) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Text(
          faq['question']!,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.green.shade800,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Text(
              faq['answer']!,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.green.shade800),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: Colors.green.shade800,
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Help & Support',
          style: GoogleFonts.poppins(
            color: Colors.green.shade800,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.green.shade800),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Frequently Asked Questions',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
            ).animate().fadeIn().slideX(),
            const SizedBox(height: 16),
            ..._faqs.map((faq) => _buildFAQItem(faq)).toList(),
            const SizedBox(height: 32),
            Text(
              'Contact Support',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
            ).animate().fadeIn().slideX(),
            const SizedBox(height: 16),
            _buildContactOption(
              title: 'Chat with Us',
              subtitle: 'Get instant help from our support team',
              icon: Icons.chat_bubble_outline,
              onTap: _openChatbot,
            ),
            _buildContactOption(
              title: 'Submit Complaint',
              subtitle: 'Let us know if something went wrong',
              icon: Icons.warning_amber_outlined,
              onTap: _submitComplaint,
            ),
            _buildContactOption(
              title: 'Give Feedback',
              subtitle: 'Help us improve our service',
              icon: Icons.star_outline,
              onTap: _submitFeedback,
            ),
            _buildContactOption(
              title: 'Email Support',
              subtitle: 'mystery12728@gmail.com',
              icon: Icons.email_outlined,
              onTap: _launchEmail,
            ),
            _buildContactOption(
              title: 'Phone Support',
              subtitle: '+91 9167415756',
              icon: Icons.phone_outlined,
              onTap: _launchPhone,
            ),
          ],
        ),
      ),
    );
  }
}
