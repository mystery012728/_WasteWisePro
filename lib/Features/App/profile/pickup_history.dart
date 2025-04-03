import 'package:flutter/material.dart';
import 'package:flutternew/Features/App/User_auth/util/smack_bar.dart';
import 'package:flutternew/Features/App/User_auth/util/screen_util.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io' show File;
import 'package:firebase_auth/firebase_auth.dart';

class PickupHistoryPage extends StatefulWidget {
  const PickupHistoryPage({Key? key}) : super(key: key);

  @override
  State<PickupHistoryPage> createState() => _PickupHistoryPageState();
}

class _PickupHistoryPageState extends State<PickupHistoryPage> {
  final Color primaryGreen = const Color(0xFF2E7D32);
  DateTime selectedStartDate = DateTime.now();
  DateTime selectedEndDate = DateTime.now();
  double totalMonthlyWeight = 0.0;
  double totalCarbonFootprint = 0.0;
  double totalEarnings = 0.0;
  bool isGeneratingPDF = false;
  int maxPagesPerDocument = 50; // Maximum pages per PDF document
  String selectedFilter = 'All';

  // Track which history type is selected
  String selectedHistoryType = 'subscription'; // Default to subscription

  // Stats for each type
  Map<String, dynamic> subscriptionStats = {
    'totalWeight': 0.0,
    'carbonFootprint': 0.0,
    'successful': 0,
    'missed': 0,
    'cancelled': 0,
  };

  Map<String, dynamic> specialDayStats = {
    'totalWeight': 0.0,
    'carbonFootprint': 0.0,
    'successful': 0,
    'missed': 0,
    'cancelled': 0,
  };

  Map<String, dynamic> scrapStats = {
    'totalWeight': 0.0,
    'totalEarnings': 0.0,
    'successful': 0,
    'missed': 0,
    'cancelled': 0,
  };

  final Map<String, double> carbonFactors = {
    'Mix waste (Wet & Dry)': 2.5,
    'Wet Waste': 1.2,
    'Dry Waste': 1.1,
    'E-Waste': 8.0,
    'Restaurant': 1.8,
    'Meat & Vegetable Stall': 2.0,
    'Plastic Waste': 6.0,
    'Others': 2.5,
    'News Paper': 1.1,
    'Office Paper(A3/A4)': 1.1,
    'Books': 1.1,
    'Cardboard': 1.3,
    'Plastic': 6.0,
    'general_waste': 2.5
  };

  @override
  void initState() {
    super.initState();
    _calculateStats();
  }

  Future<void> _calculateStats() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return;
    }

    final startDate =
        DateTime(selectedStartDate.year, selectedStartDate.month, 1);
    final endDate =
        DateTime(selectedEndDate.year, selectedEndDate.month + 1, 0);

    // Reset stats
    subscriptionStats = {
      'totalWeight': 0.0,
      'carbonFootprint': 0.0,
      'successful': 0,
      'missed': 0,
      'cancelled': 0,
    };

    specialDayStats = {
      'totalWeight': 0.0,
      'carbonFootprint': 0.0,
      'successful': 0,
      'missed': 0,
      'cancelled': 0,
    };

    scrapStats = {
      'totalWeight': 0.0,
      'totalEarnings': 0.0,
      'successful': 0,
      'missed': 0,
      'cancelled': 0,
    };

    // Calculate successful pickups stats
    await _calculatePickupTypeStats(
      'successful_pickups',
      startDate,
      endDate,
      userId: currentUser.uid,
    );

    // Calculate missed pickups stats
    await _calculatePickupTypeStats(
      'missed_pickups',
      startDate,
      endDate,
      userId: currentUser.uid,
      isSuccessful: false,
    );

    // Calculate cancelled pickups stats
    await _calculatePickupTypeStats(
      'cancelled_pickups',
      startDate,
      endDate,
      userId: currentUser.uid,
      isSuccessful: false,
      isCancelled: true,
    );

    setState(() {
      // Set total stats based on selected history type
      if (selectedHistoryType == 'subscription') {
        totalMonthlyWeight = subscriptionStats['totalWeight'];
        totalCarbonFootprint = subscriptionStats['carbonFootprint'];
      } else if (selectedHistoryType == 'special_day') {
        totalMonthlyWeight = specialDayStats['totalWeight'];
        totalCarbonFootprint = specialDayStats['carbonFootprint'];
      } else {
        totalMonthlyWeight = scrapStats['totalWeight'];
        totalEarnings = scrapStats['totalEarnings'];
      }
    });
  }

  Future<void> _calculatePickupTypeStats(
      String collection, DateTime startDate, DateTime endDate,
      {bool isSuccessful = true,
      bool isCancelled = false,
      required String userId}) async {
    final dateField = isCancelled ? 'date' : 'pickup_date';

    var query = FirebaseFirestore.instance
        .collection(collection)
        .where(dateField, isGreaterThanOrEqualTo: startDate)
        .where(dateField, isLessThanOrEqualTo: endDate)
        .where('customer_id', isEqualTo: userId);

    final pickups = await query.get();

    for (var doc in pickups.docs) {
      final data = doc.data();

      // Determine if this is a subscription, special day, or scrap pickup
      final bool isSpecialDay = data['special_day_id'] != null;
      final bool isSubscription = data['subscription_id'] != null;
      final bool isScrap = data['waste_type'] == 'scrap';

      // Update count stats
      if (isScrap) {
        if (isSuccessful)
          scrapStats['successful']++;
        else if (isCancelled)
          scrapStats['cancelled']++;
        else
          scrapStats['missed']++;
      } else if (isSpecialDay) {
        if (isSuccessful)
          specialDayStats['successful']++;
        else if (isCancelled)
          specialDayStats['cancelled']++;
        else
          specialDayStats['missed']++;
      } else if (isSubscription) {
        if (isSuccessful)
          subscriptionStats['successful']++;
        else if (isCancelled)
          subscriptionStats['cancelled']++;
        else
          subscriptionStats['missed']++;
      }

      // Only calculate weight and carbon footprint/earnings for successful pickups
      if (!isSuccessful) continue;

      double weight = 0.0;
      double carbonFootprint = 0.0;
      double earnings = 0.0;

      // Process weights for subscription pickups
      if (isSubscription) {
        if (data['waste_weights'] != null) {
          final wasteWeights = data['waste_weights'] as Map<String, dynamic>;
          wasteWeights.forEach((type, typeWeight) {
            if (typeWeight is num) {
              final double weightValue = typeWeight.toDouble();
              weight += weightValue;
              double carbonFactor = carbonFactors[type] ?? 2.5;
              carbonFootprint += weightValue * carbonFactor;
            }
          });
        }
      }
      // Process weights for special day pickups
      else if (isSpecialDay) {
        // Check for household waste weights
        if (data['household_waste_weights'] != null) {
          final householdWeights =
              data['household_waste_weights'] as Map<String, dynamic>;
          householdWeights.forEach((type, typeWeight) {
            if (typeWeight is num) {
              final double weightValue = typeWeight.toDouble();
              weight += weightValue;
              double carbonFactor = carbonFactors[type] ?? 2.5;
              carbonFootprint += weightValue * carbonFactor;
            }
          });
        }

        // Check for commercial waste weights
        if (data['commercial_waste_weights'] != null) {
          final commercialWeights =
              data['commercial_waste_weights'] as Map<String, dynamic>;
          commercialWeights.forEach((type, typeWeight) {
            if (typeWeight is num) {
              final double weightValue = typeWeight.toDouble();
              weight += weightValue;
              double carbonFactor = carbonFactors[type] ?? 2.5;
              carbonFootprint += weightValue * carbonFactor;
            }
          });
        }

        // Check for scrap weights
        if (data['scrap_weights'] != null) {
          final scrapWeights = data['scrap_weights'] as Map<String, dynamic>;
          scrapWeights.forEach((type, typeWeight) {
            if (typeWeight is num) {
              final double weightValue = typeWeight.toDouble();
              weight += weightValue;
              double carbonFactor = carbonFactors[type] ?? 2.5;
              carbonFootprint += weightValue * carbonFactor;
            }
          });
        }

        // Fallback to waste_weights if the specific categories aren't found
        if (weight == 0.0 && data['waste_weights'] != null) {
          final wasteWeights = data['waste_weights'] as Map<String, dynamic>;
          wasteWeights.forEach((type, typeWeight) {
            if (typeWeight is num) {
              final double weightValue = typeWeight.toDouble();
              weight += weightValue;
              double carbonFactor = carbonFactors[type] ?? 2.5;
              carbonFootprint += weightValue * carbonFactor;
            }
          });
        }
      }
      // Process weights for scrap pickups
      else if (isScrap) {
        if (data['scrap_weights'] != null) {
          final scrapWeights = data['scrap_weights'] as Map<String, dynamic>;
          scrapWeights.forEach((type, typeWeight) {
            if (typeWeight is num) {
              final double weightValue = typeWeight.toDouble();
              weight += weightValue;
              // Calculate earnings based on scrap type
              double pricePerKg = 0.0;
              switch (type) {
                case 'News Paper':
                  pricePerKg = 15;
                  break;
                case 'Office Paper(A3/A4)':
                  pricePerKg = 15;
                  break;
                case 'Books':
                  pricePerKg = 12;
                  break;
                case 'Cardboard':
                  pricePerKg = 8;
                  break;
                case 'Plastic':
                  pricePerKg = 10;
                  break;
              }
              earnings += weightValue * pricePerKg;
            }
          });
        }
      }

      // Add to appropriate stats
      if (isScrap) {
        scrapStats['totalWeight'] += weight;
        scrapStats['totalEarnings'] += earnings;
      } else if (isSpecialDay) {
        specialDayStats['totalWeight'] += weight;
        specialDayStats['carbonFootprint'] += carbonFootprint;
      } else if (isSubscription) {
        subscriptionStats['totalWeight'] += weight;
        subscriptionStats['carbonFootprint'] += carbonFootprint;
      }
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTime? pickedStartDate = await showDatePicker(
      context: context,
      initialDate: selectedStartDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedStartDate != null && pickedStartDate != selectedStartDate) {
      final DateTime? pickedEndDate = await showDatePicker(
        context: context,
        initialDate: selectedEndDate,
        firstDate: pickedStartDate,
        lastDate: DateTime(2101),
      );

      if (pickedEndDate != null && pickedEndDate != selectedEndDate) {
        setState(() {
          selectedStartDate = pickedStartDate;
          selectedEndDate = pickedEndDate;
        });
        _calculateStats(); // Recalculate stats after date selection
      }
    }
  }

  Future<void> _generateAndSharePDF() async {
    if (isGeneratingPDF) return;

    setState(() {
      isGeneratingPDF = true;
    });

    try {
      final startDate =
          DateTime(selectedStartDate.year, selectedStartDate.month, 1);
      final endDate =
          DateTime(selectedEndDate.year, selectedEndDate.month + 1, 0);

      // Fetch all types of pickups
      final successfulPickups = await FirebaseFirestore.instance
          .collection('successful_pickups')
          .where('pickup_date', isGreaterThanOrEqualTo: startDate)
          .where('pickup_date', isLessThanOrEqualTo: endDate)
          .get();

      final missedPickups = await FirebaseFirestore.instance
          .collection('missed_pickups')
          .where('pickup_date', isGreaterThanOrEqualTo: startDate)
          .where('pickup_date', isLessThanOrEqualTo: endDate)
          .get();

      final cancelledPickups = await FirebaseFirestore.instance
          .collection('cancelled_pickups')
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThanOrEqualTo: endDate)
          .get();

      // Combine all pickups and filter by history type
      List<Map<String, dynamic>> allPickups = [];

      // Add successful pickups
      for (var doc in successfulPickups.docs) {
        final data = doc.data();
        if ((selectedHistoryType == 'subscription' &&
                data['subscription_id'] != null) ||
            (selectedHistoryType == 'special_day' &&
                data['special_day_id'] != null)) {
          allPickups.add({
            ...data,
            'status': 'successful',
            'date': data['pickup_date'],
          });
        }
      }

      // Add missed pickups
      for (var doc in missedPickups.docs) {
        final data = doc.data();
        if ((selectedHistoryType == 'subscription' &&
                data['subscription_id'] != null) ||
            (selectedHistoryType == 'special_day' &&
                data['special_day_id'] != null)) {
          allPickups.add({
            ...data,
            'status': 'missed',
            'date': data['pickup_date'],
          });
        }
      }

      // Add cancelled pickups
      for (var doc in cancelledPickups.docs) {
        final data = doc.data();
        if ((selectedHistoryType == 'subscription' &&
                data['subscription_id'] != null) ||
            (selectedHistoryType == 'special_day' &&
                data['special_day_id'] != null)) {
          allPickups.add({
            ...data,
            'status': 'cancelled',
            'date': data['date'],
          });
        }
      }

      // Sort all pickups by date
      allPickups.sort((a, b) {
        final aDate = (a['date'] as Timestamp).toDate();
        final bDate = (b['date'] as Timestamp).toDate();
        return aDate.compareTo(bDate);
      });

      // Chunk the pickups for PDF generation
      final List<List<Map<String, dynamic>>> chunks = [];
      final int docsPerChunk = 10;

      for (var i = 0; i < allPickups.length; i += docsPerChunk) {
        final end = (i + docsPerChunk < allPickups.length)
            ? i + docsPerChunk
            : allPickups.length;
        chunks.add(allPickups.sublist(i, end));
      }

      // Get stats based on selected history type
      final stats = selectedHistoryType == 'subscription'
          ? subscriptionStats
          : selectedHistoryType == 'special_day'
              ? specialDayStats
              : scrapStats;

      final List<File> pdfFiles = [];
      int fileCounter = 1;

      for (var chunk in chunks) {
        final pdf = pw.Document();
        double totalWeight = 0;
        double totalCarbonFootprint = 0;

        // Calculate total weight and carbon footprint for this chunk
        for (var data in chunk) {
          if (data['status'] == 'successful') {
            double docWeight = 0.0;
            double docCarbonFootprint = 0.0;

            if (selectedHistoryType == 'subscription' &&
                data['subscription_id'] != null) {
              // Handle subscription pickups
              final wasteWeights =
                  data['waste_weights'] as Map<String, dynamic>?;
              if (wasteWeights != null) {
                wasteWeights.forEach((type, weight) {
                  if (weight is num) {
                    final double weightValue = weight.toDouble();
                    docWeight += weightValue;
                    double carbonFactor = carbonFactors[type] ?? 2.5;
                    docCarbonFootprint += weightValue * carbonFactor;
                  }
                });
              }
            } else if (selectedHistoryType == 'special_day' &&
                data['special_day_id'] != null) {
              // Handle special day pickups - check all possible weight fields
              // Check household waste weights
              if (data['household_waste_weights'] != null) {
                final weights =
                    data['household_waste_weights'] as Map<String, dynamic>;
                weights.forEach((type, weight) {
                  if (weight is num) {
                    final double weightValue = weight.toDouble();
                    docWeight += weightValue;
                    double carbonFactor = carbonFactors[type] ?? 2.5;
                    docCarbonFootprint += weightValue * carbonFactor;
                  }
                });
              }

              // Check commercial waste weights
              if (data['commercial_waste_weights'] != null) {
                final weights =
                    data['commercial_waste_weights'] as Map<String, dynamic>;
                weights.forEach((type, weight) {
                  if (weight is num) {
                    final double weightValue = weight.toDouble();
                    docWeight += weightValue;
                    double carbonFactor = carbonFactors[type] ?? 2.5;
                    docCarbonFootprint += weightValue * carbonFactor;
                  }
                });
              }

              // Check scrap weights
              if (data['scrap_weights'] != null) {
                final weights = data['scrap_weights'] as Map<String, dynamic>;
                weights.forEach((type, weight) {
                  if (weight is num) {
                    final double weightValue = weight.toDouble();
                    docWeight += weightValue;
                    double carbonFactor = carbonFactors[type] ?? 2.5;
                    docCarbonFootprint += weightValue * carbonFactor;
                  }
                });
              }

              // Fallback to waste_weights if specific categories aren't found
              if (docWeight == 0.0 && data['waste_weights'] != null) {
                final weights = data['waste_weights'] as Map<String, dynamic>;
                weights.forEach((type, weight) {
                  if (weight is num) {
                    final double weightValue = weight.toDouble();
                    docWeight += weightValue;
                    double carbonFactor = carbonFactors[type] ?? 2.5;
                    docCarbonFootprint += weightValue * carbonFactor;
                  }
                });
              }
            }

            totalWeight += docWeight;
            totalCarbonFootprint += docCarbonFootprint;
          }
        }

        pdf.addPage(
          pw.MultiPage(
            maxPages: maxPagesPerDocument,
            pageTheme: pw.PageTheme(
              pageFormat: PdfPageFormat.a4,
              theme: pw.ThemeData.withFont(
                base: pw.Font.helvetica(),
                bold: pw.Font.helveticaBold(),
              ),
            ),
            header: (context) => _buildPDFHeader(context),
            footer: (context) => _buildPDFFooter(context),
            build: (context) => [
              _buildPDFSummarySection(
                totalWeight,
                totalCarbonFootprint,
                stats['successful'],
                stats['missed'],
                stats['cancelled'],
              ),
              _buildPDFAllPickupsSection(chunk),
            ],
          ),
        );

        final output = await getTemporaryDirectory();
        final historyType = selectedHistoryType == 'subscription'
            ? 'Subscription'
            : selectedHistoryType == 'special_day'
                ? 'Special Day'
                : 'Scrap';
        final file = File(
          '${output.path}/WasteWisePro_${historyType}_Report_${DateFormat('MMM_yyyy').format(selectedStartDate)}_part$fileCounter.pdf',
        );
        await file.writeAsBytes(await pdf.save());
        pdfFiles.add(file);
        fileCounter++;
      }

      if (pdfFiles.isNotEmpty) {
        final historyType = selectedHistoryType == 'subscription'
            ? 'Subscription'
            : selectedHistoryType == 'special_day'
                ? 'Special Day'
                : 'Scrap';
        await Share.shareFiles(
          pdfFiles.map((f) => f.path!).toList(),
          text:
              'Waste Wise Pro - $historyType Pickup History Report (${DateFormat('MMM d').format(selectedStartDate)} - ${DateFormat('MMM d, y').format(selectedEndDate)})',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        isGeneratingPDF = false;
      });
    }
  }

  pw.Widget _buildPDFHeader(pw.Context context) {
    final historyType = selectedHistoryType == 'subscription'
        ? 'Subscription'
        : selectedHistoryType == 'special_day'
            ? 'Special Day'
            : 'Scrap';

    return pw.Container(
      padding: pw.EdgeInsets.all(20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            'Waste Wise Pro',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green900,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            '$historyType Pickup History Report',
            style: pw.TextStyle(
              fontSize: 18,
              color: PdfColors.green800,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            '${DateFormat('MMM d, y').format(selectedStartDate)} - ${DateFormat('MMM d, y').format(selectedEndDate)}',
            style: pw.TextStyle(
              fontSize: 14,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFFooter(pw.Context context) {
    return pw.Container(
      padding: pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated on ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey600,
            ),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFSummarySection(
    double totalWeight,
    double totalCarbonFootprint,
    int successfulPickups,
    int missedPickups,
    int cancelledPickups,
  ) {
    return pw.Container(
      padding: pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.green200),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Center(
            child: pw.Text(
              'Summary',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green900,
              ),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildPDFSummaryItem(
                  'Total Weight', '${totalWeight.toStringAsFixed(2)} kg'),
              _buildPDFSummaryItem('Carbon Footprint',
                  '${totalCarbonFootprint.toStringAsFixed(2)} kg CO2e'),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildPDFSummaryItem(
                  'Successful Pickups', successfulPickups.toString()),
              _buildPDFSummaryItem('Missed Pickups', missedPickups.toString()),
              _buildPDFSummaryItem(
                  'Cancelled Pickups', cancelledPickups.toString()),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFSummaryItem(String label, String value) {
    return pw.Container(
      padding: pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.green100),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green800,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 12,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFAllPickupsSection(List<Map<String, dynamic>> pickups) {
    return pw.Container(
      margin: pw.EdgeInsets.only(top: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Pickup Details',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green900,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: pw.FlexColumnWidth(1.2), // Date
              1: pw.FlexColumnWidth(0.8), // Time
              2: pw.FlexColumnWidth(1.0), // Status
              3: pw.FlexColumnWidth(
                  2.0), // Waste Type - more space for longer text
              4: pw.FlexColumnWidth(
                  1.5), // Weight - more space for detailed weights
            },
            children: [
              // Table header
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                ),
                children: [
                  _buildPDFTableHeader('Date'),
                  _buildPDFTableHeader('Time'),
                  _buildPDFTableHeader('Status'),
                  _buildPDFTableHeader('Waste Type'),
                  _buildPDFTableHeader('Weight (kg)'),
                ],
              ),
              // Table rows
              ...pickups.map((data) {
                final timestamp = data['date'] as Timestamp?;
                final date = timestamp?.toDate() ?? DateTime.now();
                final status = data['status'] ?? 'unknown';

                // Get status color
                PdfColor statusColor;
                switch (status) {
                  case 'successful':
                    statusColor = PdfColors.green700;
                    break;
                  case 'missed':
                    statusColor = PdfColors.orange700;
                    break;
                  case 'cancelled':
                    statusColor = PdfColors.red700;
                    break;
                  default:
                    statusColor = PdfColors.grey700;
                }

                return pw.TableRow(
                  children: [
                    _buildPDFTableCell(DateFormat('dd/MM/yyyy').format(date)),
                    _buildPDFTableCell(DateFormat('HH:mm').format(date)),
                    _buildPDFTableCell(
                      status.toUpperCase(),
                      textColor: statusColor,
                      isBold: true,
                    ),
                    _buildPDFTableCell(_getWasteTypeString(data),
                        allowWrap: true),
                    _buildPDFTableCell(
                        status == 'successful' ? _getWeightString(data) : 'N/A',
                        allowWrap: true),
                  ],
                );
              }).toList(),
            ],
          ),
        ],
      ),
    );
  }

  // Update the _buildPDFTableCell method to handle text wrapping
  pw.Widget _buildPDFTableCell(String text,
      {PdfColor? textColor, bool isBold = false, bool allowWrap = false}) {
    return pw.Container(
      padding: pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: textColor,
          fontWeight: isBold ? pw.FontWeight.bold : null,
        ),
        textAlign: pw.TextAlign.left,
        maxLines:
            allowWrap ? null : 1, // Allow multiple lines for wrapping text
        overflow: allowWrap ? pw.TextOverflow.span : pw.TextOverflow.clip,
      ),
    );
  }

  // Improve the waste type string formatting to handle long lists better
  String _getWasteTypeString(Map<String, dynamic> data) {
    List<String> types = [];

    // For subscription pickups
    if (data['waste_weights'] != null) {
      types.addAll((data['waste_weights'] as Map<String, dynamic>)
          .keys
          .map((k) => k.replaceAll('_', ' ').toUpperCase()));
    }

    // For special day pickups
    if (data['household_waste'] != null) {
      types.addAll((data['household_waste'] as List<dynamic>)
          .map((k) => k.toString().replaceAll('_', ' ').toUpperCase()));
    }

    if (data['commercial_waste'] != null) {
      types.addAll((data['commercial_waste'] as List<dynamic>)
          .map((k) => k.toString().replaceAll('_', ' ').toUpperCase()));
    }

    if (data['scrap_types'] != null) {
      types.addAll((data['scrap_types'] as List<dynamic>)
          .map((k) => k.toString().replaceAll('_', ' ').toUpperCase()));
    }

    // If no types found, use waste_type
    if (types.isEmpty) {
      return (data['waste_type'] ?? 'general_waste')
          .replaceAll('_', ' ')
          .toUpperCase();
    }

    // Join with line breaks if there are many types to improve readability
    if (types.length > 3) {
      return types.join('\n');
    }

    return types.join(', ');
  }

  // Improve the weight string formatting to handle multiple weights better
  String _getWeightString(Map<String, dynamic> data) {
    double totalWeight = 0.0;
    List<String> weightStrings = [];

    // For subscription pickups
    if (data['waste_weights'] != null) {
      final weights = data['waste_weights'] as Map<String, dynamic>;
      weights.forEach((type, weight) {
        if (weight is num) {
          totalWeight += weight.toDouble();
          weightStrings.add(
              '${type.replaceAll('_', ' ')}: ${weight.toDouble().toStringAsFixed(2)} kg');
        }
      });
    }

    // For special day pickups
    if (data['household_waste_weights'] != null) {
      final weights = data['household_waste_weights'] as Map<String, dynamic>;
      weights.forEach((type, weight) {
        if (weight is num) {
          totalWeight += weight.toDouble();
          weightStrings.add(
              '${type.replaceAll('_', ' ')}: ${weight.toDouble().toStringAsFixed(2)} kg');
        }
      });
    }

    if (data['commercial_waste_weights'] != null) {
      final weights = data['commercial_waste_weights'] as Map<String, dynamic>;
      weights.forEach((type, weight) {
        if (weight is num) {
          totalWeight += weight.toDouble();
          weightStrings.add(
              '${type.replaceAll('_', ' ')}: ${weight.toDouble().toStringAsFixed(2)} kg');
        }
      });
    }

    if (data['scrap_weights'] != null) {
      final weights = data['scrap_weights'] as Map<String, dynamic>;
      weights.forEach((type, weight) {
        if (weight is num) {
          totalWeight += weight.toDouble();
          weightStrings.add(
              '${type.replaceAll('_', ' ')}: ${weight.toDouble().toStringAsFixed(2)} kg');
        }
      });
    }

    // If no weights found, use weight field
    if (weightStrings.isEmpty) {
      return '${data['weight']?.toString() ?? 'N/A'} kg';
    }

    // If there are multiple weights, show total and details
    if (weightStrings.length > 1) {
      return 'Total: ${totalWeight.toStringAsFixed(2)} kg\n' +
          weightStrings.join('\n');
    }

    return weightStrings.join('\n');
  }

  pw.Widget _buildPDFTableHeader(String text) {
    return pw.Container(
      padding: pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.green900,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pickup History',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
          ),
        ),
        backgroundColor: primaryGreen,
        actions: [
          if (isGeneratingPDF)
            Center(
              child: Padding(
                padding: EdgeInsets.all(8.w),
                child: SizedBox(
                  height: 20.h,
                  width: 20.w,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.download),
              onPressed: _generateAndSharePDF,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHistoryTypeSelector(),
            _buildDateRangeSelector(),
            _buildStats(),
            DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  TabBar(
                    labelColor: primaryGreen,
                    unselectedLabelColor: Colors.grey,
                    labelStyle: GoogleFonts.poppins(fontSize: 14.sp),
                    unselectedLabelStyle: GoogleFonts.poppins(fontSize: 14.sp),
                    tabs: [
                      Tab(text: 'Successful'),
                      Tab(text: 'Missed'),
                      Tab(text: 'Cancelled'),
                    ],
                  ),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: TabBarView(
                      children: [
                        _buildPickupList('successful_pickups'),
                        _buildPickupList('missed_pickups'),
                        _buildPickupList('cancelled_pickups'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTypeSelector() {
    return Container(
      padding: EdgeInsets.all(16.w),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  selectedHistoryType = 'subscription';
                  totalMonthlyWeight = subscriptionStats['totalWeight'];
                  totalCarbonFootprint = subscriptionStats['carbonFootprint'];
                });
                _calculateStats();
              },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                decoration: BoxDecoration(
                  color: selectedHistoryType == 'subscription'
                      ? primaryGreen
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Center(
                  child: Text(
                    'Subscription History',
                    style: GoogleFonts.poppins(
                      color: selectedHistoryType == 'subscription'
                          ? Colors.white
                          : Colors.black,
                      fontWeight: FontWeight.w500,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  selectedHistoryType = 'special_day';
                  totalMonthlyWeight = specialDayStats['totalWeight'];
                  totalCarbonFootprint = specialDayStats['carbonFootprint'];
                });
                _calculateStats();
              },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                decoration: BoxDecoration(
                  color: selectedHistoryType == 'special_day'
                      ? primaryGreen
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Center(
                  child: Text(
                    'Special Day History',
                    style: GoogleFonts.poppins(
                      color: selectedHistoryType == 'special_day'
                          ? Colors.white
                          : Colors.black,
                      fontWeight: FontWeight.w500,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  selectedHistoryType = 'scrap';
                  totalMonthlyWeight = scrapStats['totalWeight'];
                  totalEarnings = scrapStats['totalEarnings'];
                });
                _calculateStats();
              },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                decoration: BoxDecoration(
                  color: selectedHistoryType == 'scrap'
                      ? primaryGreen
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Center(
                  child: Text(
                    'Scrap History',
                    style: GoogleFonts.poppins(
                      color: selectedHistoryType == 'scrap'
                          ? Colors.white
                          : Colors.black,
                      fontWeight: FontWeight.w500,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeSelector() {
    return Container(
      padding: EdgeInsets.all(16.w),
      child: InkWell(
        onTap: () => _selectDateRange(context),
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${DateFormat('MMM d, y').format(selectedStartDate)} - ${DateFormat('MMM d, y').format(selectedEndDate)}',
                style: GoogleFonts.poppins(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(Icons.calendar_today, color: primaryGreen),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStats() {
    final stats = selectedHistoryType == 'subscription'
        ? subscriptionStats
        : selectedHistoryType == 'special_day'
            ? specialDayStats
            : scrapStats;
    final historyType = selectedHistoryType == 'subscription'
        ? 'Subscription'
        : selectedHistoryType == 'special_day'
            ? 'Special Day'
            : 'Scrap';

    return Container(
      padding: EdgeInsets.all(12.w),
      margin: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$historyType Statistics',
            style: GoogleFonts.poppins(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: primaryGreen,
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatCard('Total Weight',
                  '${stats['totalWeight'].toStringAsFixed(2)} kg', Icons.scale),
              _buildStatCard(
                  selectedHistoryType == 'scrap'
                      ? 'Total Earnings'
                      : 'Carbon Footprint',
                  selectedHistoryType == 'scrap'
                      ? '₹${stats['totalEarnings'].toStringAsFixed(2)}'
                      : '${stats['carbonFootprint'].toStringAsFixed(2)} kg CO₂e',
                  selectedHistoryType == 'scrap'
                      ? Icons.attach_money
                      : Icons.eco),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPickupStatCard('Successful', stats['successful'].toString(),
                  Icons.check_circle, Colors.green),
              _buildPickupStatCard('Missed', stats['missed'].toString(),
                  Icons.error, Colors.orange),
              _buildPickupStatCard('Cancelled', stats['cancelled'].toString(),
                  Icons.cancel, Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12.w),
        margin: EdgeInsets.symmetric(horizontal: 4.w),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: primaryGreen, size: 24.w),
            SizedBox(height: 4.h),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickupStatCard(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(8.w),
        margin: EdgeInsets.symmetric(horizontal: 2.w),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20.w),
            SizedBox(height: 2.h),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 10.sp,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickupList(String collection) {
    final startDate =
        DateTime(selectedStartDate.year, selectedStartDate.month, 1);
    final endDate =
        DateTime(selectedEndDate.year, selectedEndDate.month + 1, 0);
    final dateField =
        collection == 'cancelled_pickups' ? 'date' : 'pickup_date';
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Center(
        child: Text(
          'Please log in to view your pickup history',
          style: GoogleFonts.poppins(color: Colors.grey),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where(dateField, isGreaterThanOrEqualTo: startDate)
          .where(dateField, isLessThanOrEqualTo: endDate)
          .where('customer_id', isEqualTo: currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No pickups found',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          );
        }

        // Filter documents based on selected history type
        final filteredDocs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          if (selectedHistoryType == 'subscription') {
            return data['subscription_id'] != null;
          } else if (selectedHistoryType == 'special_day') {
            return data['special_day_id'] != null;
          } else {
            return data['waste_type'] == 'scrap';
          }
        }).toList();

        if (filteredDocs.isEmpty) {
          return Center(
            child: Text(
              'No ${selectedHistoryType == "subscription" ? "subscription" : selectedHistoryType == 'special_day' ? 'special day' : 'scrap'} pickups found',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildPickupCard(data, collection);
          },
        );
      },
    );
  }

  Widget _buildPickupCard(Map<String, dynamic> data, String collection) {
    final timestamp = collection == 'cancelled_pickups'
        ? data['date'] as Timestamp?
        : data['pickup_date'] as Timestamp?;
    final date = timestamp != null ? timestamp.toDate() : DateTime.now();

    List<Widget> wasteDetails = [];
    double totalWeight = 0.0;

    // For subscription pickups
    if (data['waste_weights'] != null) {
      final weights = data['waste_weights'] as Map<String, dynamic>;
      weights.forEach((type, weight) {
        if (weight is num) {
          totalWeight += weight.toDouble();
          wasteDetails.add(
            Text(
              '$type: ${weight.toString()} kg',
              style: GoogleFonts.poppins(),
            ),
          );
        }
      });
    }

    // For special day pickups - check all possible weight fields
    if (data['household_waste_weights'] != null) {
      final weights = data['household_waste_weights'] as Map<String, dynamic>;
      weights.forEach((type, weight) {
        if (weight is num) {
          totalWeight += weight.toDouble();
          wasteDetails.add(
            Text(
              'Household $type: ${weight.toString()} kg',
              style: GoogleFonts.poppins(),
            ),
          );
        }
      });
    }

    if (data['commercial_waste_weights'] != null) {
      final weights = data['commercial_waste_weights'] as Map<String, dynamic>;
      weights.forEach((type, weight) {
        if (weight is num) {
          totalWeight += weight.toDouble();
          wasteDetails.add(
            Text(
              'Commercial $type: ${weight.toString()} kg',
              style: GoogleFonts.poppins(),
            ),
          );
        }
      });
    }

    if (data['scrap_weights'] != null) {
      final weights = data['scrap_weights'] as Map<String, dynamic>;
      weights.forEach((type, weight) {
        if (weight is num) {
          totalWeight += weight.toDouble();
          wasteDetails.add(
            Text(
              'Scrap $type: ${weight.toString()} kg',
              style: GoogleFonts.poppins(),
            ),
          );
        }
      });
    }

    // If no weights found, use weight field
    if (wasteDetails.isEmpty) {
      final weight = data['weight']?.toString() ?? 'N/A';
      final type = data['waste_type'] ?? 'general_waste';
      wasteDetails.add(
        Text(
          'Type: ${type.replaceAll('_', ' ').toUpperCase()}\nWeight: $weight kg',
          style: GoogleFonts.poppins(),
        ),
      );
    }

    // Add total weight if multiple waste types
    if (wasteDetails.length > 1) {
      wasteDetails.insert(
        0,
        Text(
          'Total Weight: ${totalWeight.toStringAsFixed(2)} kg',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: ListTile(
        leading: Icon(
          collection == 'successful_pickups'
              ? Icons.check_circle
              : collection == 'missed_pickups'
                  ? Icons.error
                  : Icons.cancel,
          color: collection == 'successful_pickups'
              ? Colors.green
              : collection == 'missed_pickups'
                  ? Colors.orange
                  : Colors.red,
          size: 24.w,
        ),
        title: Text(
          DateFormat('dd/MM/yyyy HH:mm').format(date),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 14.sp,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: wasteDetails.map((widget) {
            if (widget is Text) {
              return Text(
                widget.data!,
                style: GoogleFonts.poppins(
                  fontSize: 12.sp,
                ),
              );
            }
            return widget;
          }).toList(),
        ),
        isThreeLine: wasteDetails.length > 1,
      ),
    );
  }
}
