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

  // Add topic-based categories for waste management
  final Map<String, List<Map<String, String>>> _wasteManagementTopics = {
    'Waste Segregation': [
      {
        'question': 'How should I segregate my waste?',
        'answer': 'Segregate waste into:\n'
            '1. Dry Waste (paper, plastic, metal, glass)\n'
            '2. Wet Waste (food scraps, garden waste)\n'
            '3. Hazardous Waste (batteries, chemicals)\n'
            '4. E-Waste (electronics, gadgets)\n'
            'Each category requires different handling methods for proper recycling.'
      },
      {
        'question': 'What goes in dry waste?',
        'answer': 'Dry waste includes:\n'
            '• Paper (newspapers, magazines, cardboard)\n'
            '• Clean plastics (bottles, containers)\n'
            '• Metal items (cans, foil)\n'
            '• Glass (bottles, jars)\n'
            '• Textile waste\n'
            'Ensure all items are clean and dry before disposal.'
      },
    ],
    'Composting': [
      {
        'question': 'What can I compost?',
        'answer': 'Compostable materials include:\n'
            '• Fruit and vegetable scraps\n'
            '• Coffee grounds and tea bags\n'
            '• Eggshells\n'
            '• Yard waste (leaves, grass clippings)\n'
            '• Paper products (uncoated)\n'
            'Avoid meat, dairy, and oily foods.'
      },
      {
        'question': 'How do I start composting?',
        'answer': 'Start composting in 4 steps:\n'
            '1. Choose a composting location\n'
            '2. Layer brown materials (dry leaves, paper)\n'
            '3. Add green materials (food scraps, grass)\n'
            '4. Maintain moisture and turn regularly\n'
            'We can provide a composting starter kit upon request.'
      },
    ],
    'Recycling Guidelines': [
      {
        'question': 'How to prepare items for recycling?',
        'answer': 'Follow these steps:\n'
            '1. Clean containers - remove food residue\n'
            '2. Dry thoroughly - moisture can contaminate\n'
            '3. Remove non-recyclable parts\n'
            '4. Flatten boxes and containers\n'
            '5. Don\'t bag recyclables unless required'
      },
      {
        'question': 'What items are not recyclable?',
        'answer': 'Common non-recyclable items:\n'
            '• Soiled paper or cardboard\n'
            '• Plastic bags and wraps\n'
            '• Styrofoam\n'
            '• Ceramics and dishes\n'
            '• Light bulbs\n'
            '• Tissues and paper towels'
      },
    ],
    'Sustainable Practices': [
      {
        'question': 'How can I reduce waste?',
        'answer': 'Reduce waste through:\n'
            '1. Use reusable bags and containers\n'
            '2. Buy products with minimal packaging\n'
            '3. Choose durable items over disposables\n'
            '4. Repair items when possible\n'
            '5. Donate usable items\n'
            '6. Practice meal planning to reduce food waste'
      },
      {
        'question': 'What are eco-friendly alternatives?',
        'answer': 'Consider these alternatives:\n'
            '• Cloth bags instead of plastic\n'
            '• Reusable water bottles\n'
            '• Bamboo or metal straws\n'
            '• Beeswax wraps instead of plastic wrap\n'
            '• Rechargeable batteries\n'
            '• Digital documents over printed'
      },
    ],
  };

  // Enhanced keywords for better topic matching
  final Map<String, List<String>> _topicKeywords = {
    'Waste Segregation': [
      'segregate',
      'separate',
      'sort',
      'dry waste',
      'wet waste',
      'hazardous',
      'ewaste',
      'electronic waste',
      'bins',
      'categories'
    ],
    'Composting': [
      'compost',
      'organic',
      'food waste',
      'garden waste',
      'decompose',
      'fertilizer',
      'soil',
      'natural',
      'biodegradable'
    ],
    'Recycling Guidelines': [
      'recycle',
      'reuse',
      'materials',
      'plastic',
      'paper',
      'glass',
      'metal',
      'preparation',
      'clean',
      'contamination'
    ],
    'Sustainable Practices': [
      'sustainable',
      'eco',
      'environment',
      'green',
      'reduce',
      'minimize',
      'alternative',
      'friendly',
      'impact'
    ],
  };

  // Session management
  String _currentSession = '';
  String _currentTopic = '';

  late final Map<String, List<Map<String, String>>> _allTopics;
  late final Map<String, List<String>> _allTopicKeywords;

  @override
  void initState() {
    super.initState();
    _initializeTopics();
    _initializeNewSession();
  }

  void _initializeTopics() {
    _allTopics = {
      'App Features': [
        {
          'question': 'How do I schedule a pickup?',
          'answer': 'To schedule a pickup:\n'
              '1. Go to the home screen\n'
              '2. Click on "Schedule Pickup" button\n'
              '3. Select your preferred date and time\n'
              '4. Choose waste categories\n'
              '5. Confirm your booking\n'
              'You\'ll receive a confirmation notification.'
        },
        {
          'question': 'How do I track my pickup?',
          'answer': 'Track your pickup through:\n'
              '1. Go to "Orders" section in your profile\n'
              '2. Find your scheduled pickup\n'
              '3. View real-time status and location\n'
              '4. Get notifications about pickup progress\n'
              '5. Rate the service after completion'
        },
        {
          'question': 'How do I manage my subscription?',
          'answer': 'Manage your subscription by:\n'
              '1. Going to "Profile" section\n'
              '2. Selecting "Subscription"\n'
              '3. View current plan and usage\n'
              '4. Upgrade or modify your plan\n'
              '5. View billing history'
        },
        {
          'question': 'How do I contact support?',
          'answer': 'Contact support through:\n'
              '1. In-app chat support\n'
              '2. Email: mystery12728@gmail.com\n'
              '3. Phone: +91 9167415756\n'
              '4. Submit complaint form\n'
              '5. Leave feedback'
        }
      ],
      'Payments & Billing': [
        {
          'question': 'What payment methods are accepted?',
          'answer': 'We accept:\n'
              '• Credit/Debit Cards\n'
              '• UPI Payments\n'
              '• Net Banking\n'
              '• Mobile Wallets\n'
              '• Cash on Pickup (for select areas)'
        },
        {
          'question': 'How do I view my payment history?',
          'answer': 'Access payment history:\n'
              '1. Go to Profile section\n'
              '2. Select "Payment History"\n'
              '3. View all transactions\n'
              '4. Download invoices\n'
              '5. Track subscription payments'
        }
      ],
      'Waste Segregation': _wasteManagementTopics['Waste Segregation']!,
      'Composting': _wasteManagementTopics['Composting']!,
      'Recycling Guidelines': _wasteManagementTopics['Recycling Guidelines']!,
      'Sustainable Practices': _wasteManagementTopics['Sustainable Practices']!,
    };

    _allTopicKeywords = {
      'App Features': [
        'schedule',
        'pickup',
        'track',
        'order',
        'subscription',
        'profile',
        'account',
        'notification',
        'booking',
        'service'
      ],
      'Payments & Billing': [
        'payment',
        'bill',
        'invoice',
        'transaction',
        'credit',
        'debit',
        'upi',
        'wallet',
        'cash',
        'price',
        'cost',
        'charge'
      ],
      'Waste Segregation': _topicKeywords['Waste Segregation']!,
      'Composting': _topicKeywords['Composting']!,
      'Recycling Guidelines': _topicKeywords['Recycling Guidelines']!,
      'Sustainable Practices': _topicKeywords['Sustainable Practices']!,
    };
  }

  void _initializeNewSession() {
    _currentSession = DateTime.now().millisecondsSinceEpoch.toString();
    _currentTopic = '';
    chatMessages.clear();
    _clearChatHistory();
  }

  Future<void> _clearChatHistory() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    // Delete old chat messages from Firestore
    final oldMessages = await _firestore
        .collection('chat_history')
        .where('userId', isEqualTo: userId)
        .get();

    for (var doc in oldMessages.docs) {
      await doc.reference.delete();
    }
  }

  String _getBotResponse(String userMessage) {
    final lowercaseMessage = userMessage.toLowerCase();

    // Handle greetings
    if (_isGreeting(lowercaseMessage)) {
      return _getWelcomeMessage();
    }

    // Handle goodbyes
    if (_isGoodbye(lowercaseMessage)) {
      return "Thank you for chatting! Feel free to return if you need help with the app or waste management tips. Have a great day! 🌱";
    }

    // Handle thank you messages
    if (_isThankYou(lowercaseMessage)) {
      return "You're welcome! I'm here to help with both app features and waste management guidance. Need anything else? 🌍";
    }

    // Identify the topic
    String detectedTopic = _identifyTopic(lowercaseMessage);
    if (detectedTopic.isNotEmpty) {
      _currentTopic = detectedTopic;
      return _getTopicIntroduction(detectedTopic);
    }

    // If we're in a topic, look for specific questions
    if (_currentTopic.isNotEmpty) {
      final topicQuestions = _allTopics[_currentTopic] ?? [];
      for (var qa in topicQuestions) {
        if (_isRelatedToQuestion(lowercaseMessage, qa['question']!)) {
          return qa['answer']!;
        }
      }
    }

    // Handle general queries
    if (lowercaseMessage.contains('help') ||
        lowercaseMessage.contains('topics')) {
      return _getAvailableTopics();
    }

    // Default response with topic suggestions
    return "I can help you with both app features and waste management. Here are all available topics:\n\n" +
        _getAvailableTopics();
  }

  bool _isGreeting(String message) {
    final greetings = [
      'hi',
      'hello',
      'hey',
      'good morning',
      'good afternoon',
      'good evening'
    ];
    return greetings.any((greeting) => message.contains(greeting));
  }

  bool _isGoodbye(String message) {
    final goodbyes = ['bye', 'goodbye', 'see you', 'thanks bye', 'exit'];
    return goodbyes.any((goodbye) => message.contains(goodbye));
  }

  bool _isThankYou(String message) {
    final thanks = ['thank', 'thanks', 'appreciate'];
    return thanks.any((thank) => message.contains(thank));
  }

  String _getWelcomeMessage() {
    return "Hello! 👋 I'm your assistant. I can help you with:\n\n" +
        "📱 App Features (scheduling, tracking, etc.)\n" +
        "💳 Payments & Billing\n" +
        "🔍 Waste Segregation\n" +
        "🌱 Composting Techniques\n" +
        "♻️ Recycling Guidelines\n" +
        "🌍 Sustainable Practices\n\n" +
        "What would you like to learn about?";
  }

  String _identifyTopic(String message) {
    for (var entry in _allTopicKeywords.entries) {
      if (entry.value.any((keyword) => message.contains(keyword))) {
        return entry.key;
      }
    }
    return '';
  }

  bool _isRelatedToQuestion(String message, String question) {
    final questionWords = question.toLowerCase().split(' ');
    final messageWords = message.split(' ');
    return questionWords.any((word) => messageWords.contains(word));
  }

  String _getTopicIntroduction(String topic) {
    final questions =
        _allTopics[topic]?.map((qa) => "• ${qa['question']}").join('\n') ?? '';
    return "Let's talk about $topic! Here are some common questions I can answer:\n\n$questions\n\nWhat would you like to know?";
  }

  String _getAvailableTopics() {
    return "Available topics:\n\n" +
        _allTopics.keys.map((topic) => "• $topic").join('\n') +
        "\n\nWhich topic interests you?";
  }

  void _openChatbot() {
    // Initialize new session when opening chatbot
    _initializeNewSession();

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
}
