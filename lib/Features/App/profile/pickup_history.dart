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
  int maxPagesPerDocument =
      20; // Reduced maximum pages per document for better handling
  int itemsPerPage = 8; // Number of items to display per page
  String selectedFilter = 'All';

  // Track which history type is selected
  String selectedHistoryType = 'subscription'; // Default to subscription

  // Stats for each type
  Map<String, dynamic> subscriptionStats = {
    'totalWeight': 0.0,
    'carbonFootprint': 0.0,
    'totalEarnings': 0.0, // Will not be displayed for subscription
    'successful': 0,
    'missed': 0,
    'cancelled': 0,
  };

  Map<String, dynamic> specialDayStats = {
    'totalWeight': 0.0,
    'carbonFootprint': 0.0,
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

  // Scrap price per kg
  final Map<String, double> scrapPrices = {
    'News Paper': 15.0,
    'Office Paper(A3/A4)': 15.0,
    'Books': 12.0,
    'Cardboard': 8.0,
    'Plastic': 10.0,
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
      'totalEarnings': 0.0,
      'successful': 0,
      'missed': 0,
      'cancelled': 0,
    };

    specialDayStats = {
      'totalWeight': 0.0,
      'carbonFootprint': 0.0,
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
        // Don't set totalEarnings for subscription
        totalEarnings = 0.0;
      } else if (selectedHistoryType == 'special_day') {
        totalMonthlyWeight = specialDayStats['totalWeight'];
        totalCarbonFootprint = specialDayStats['carbonFootprint'];
        totalEarnings = specialDayStats['totalEarnings'];
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

      // Determine if this is a subscription or special day pickup
      final bool isSpecialDay = data['special_day_id'] != null;
      final bool isSubscription = data['subscription_id'] != null;
      final bool isScrap =
          data['waste_type'] == 'scrap' || data['scrap_details_id'] != null;

      // Update count stats
      if (isSpecialDay) {
        if (isSuccessful)
          specialDayStats['successful']++;
        else if (isCancelled) specialDayStats['cancelled']++;
      } else if (isSubscription) {
        if (isSuccessful)
          subscriptionStats['successful']++;
        else if (isCancelled) subscriptionStats['cancelled']++;
      }

      // Only calculate weight, carbon footprint, and earnings for successful pickups
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

        // Check for scrap weights and calculate earnings
        if (data['scrap_weights'] != null) {
          final scrapWeights = data['scrap_weights'] as Map<String, dynamic>;
          scrapWeights.forEach((type, typeWeight) {
            if (typeWeight is num) {
              final double weightValue = typeWeight.toDouble();
              weight += weightValue;
              double carbonFactor = carbonFactors[type] ?? 2.5;
              carbonFootprint += weightValue * carbonFactor;

              // Calculate earnings for scrap items
              double pricePerKg = scrapPrices[type] ?? 0.0;
              earnings += weightValue * pricePerKg;
            }
          });
        }

        // Get total scrap price directly if available
        if (data['total_scrap_price'] != null &&
            data['total_scrap_price'] is num) {
          earnings = (data['total_scrap_price'] as num).toDouble();
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

              // Calculate earnings if it's a scrap type
              if (scrapPrices.containsKey(type)) {
                earnings += weightValue * scrapPrices[type]!;
              }
            }
          });
        }
      }

      // Add to appropriate stats
      if (isSpecialDay) {
        specialDayStats['totalWeight'] += weight;
        specialDayStats['carbonFootprint'] += carbonFootprint;
        specialDayStats['totalEarnings'] += earnings;
      } else if (isSubscription) {
        subscriptionStats['totalWeight'] += weight;
        subscriptionStats['carbonFootprint'] += carbonFootprint;
        // Still track earnings for subscription pickups for PDF reports
        subscriptionStats['totalEarnings'] += earnings;
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
      // Calculate how many items we can fit in one document
      final int itemsPerDocument = maxPagesPerDocument * itemsPerPage;

      for (var i = 0; i < allPickups.length; i += itemsPerDocument) {
        final end = (i + itemsPerDocument < allPickups.length)
            ? i + itemsPerDocument
            : allPickups.length;
        chunks.add(allPickups.sublist(i, end));
      }

      // Get stats based on selected history type
      final stats = selectedHistoryType == 'subscription'
          ? subscriptionStats
          : specialDayStats;

      final List<File> pdfFiles = [];
      int fileCounter = 1;

      for (var chunk in chunks) {
        final pdf = pw.Document();
        double totalWeight = 0;
        double totalCarbonFootprint = 0;
        double totalEarnings = 0;

        // Calculate total weight, carbon footprint, and earnings for this chunk
        for (var data in chunk) {
          if (data['status'] == 'successful') {
            double docWeight = 0.0;
            double docCarbonFootprint = 0.0;
            double docEarnings = 0.0;

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

                    // Calculate earnings if it's a scrap type
                    if (scrapPrices.containsKey(type)) {
                      docEarnings += weightValue * scrapPrices[type]!;
                    }
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

              // Check scrap weights and calculate earnings
              if (data['scrap_weights'] != null) {
                final weights = data['scrap_weights'] as Map<String, dynamic>;
                weights.forEach((type, weight) {
                  if (weight is num) {
                    final double weightValue = weight.toDouble();
                    docWeight += weightValue;
                    double carbonFactor = carbonFactors[type] ?? 2.5;
                    docCarbonFootprint += weightValue * carbonFactor;

                    // Calculate earnings for scrap items
                    double pricePerKg = scrapPrices[type] ?? 0.0;
                    docEarnings += weightValue * pricePerKg;
                  }
                });
              }

              // Get total scrap price directly if available
              if (data['total_scrap_price'] != null &&
                  data['total_scrap_price'] is num) {
                docEarnings = (data['total_scrap_price'] as num).toDouble();
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

                    // Calculate earnings if it's a scrap type
                    if (scrapPrices.containsKey(type)) {
                      docEarnings += weightValue * scrapPrices[type]!;
                    }
                  }
                });
              }
            }

            totalWeight += docWeight;
            totalCarbonFootprint += docCarbonFootprint;
            totalEarnings += docEarnings;
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
                selectedHistoryType == 'special_day'
                    ? totalEarnings
                    : 0.0, // Only show earnings for special day
                stats['successful'],
                stats['missed'],
                stats['cancelled'],
              ),
              // Split the chunk into pages
              for (var i = 0; i < chunk.length; i += itemsPerPage)
                _buildPDFAllPickupsSection(
                  chunk.sublist(
                    i,
                    i + itemsPerPage > chunk.length
                        ? chunk.length
                        : i + itemsPerPage,
                  ),
                ),
            ],
          ),
        );

        final output = await getTemporaryDirectory();
        final historyType = selectedHistoryType == 'subscription'
            ? 'Subscription'
            : 'Special Day';
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
            : 'Special Day';
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
    final historyType =
        selectedHistoryType == 'subscription' ? 'Subscription' : 'Special Day';

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
    double totalEarnings,
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
              // Only show earnings for special day history
              selectedHistoryType == 'special_day'
                  ? _buildPDFSummaryItem(
                      'Total Earnings', '₹${totalEarnings.toStringAsFixed(2)}')
                  : pw.Container(),
              _buildPDFSummaryItem(
                  'Successful Pickups', successfulPickups.toString()),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
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
              3: pw.FlexColumnWidth(2.0), // Waste Type
              4: pw.FlexColumnWidth(1.5), // Weight
              5: pw.FlexColumnWidth(1.5), // Earnings (only for special day)
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
                  // Only show earnings column for special day
                  selectedHistoryType == 'special_day'
                      ? _buildPDFTableHeader('Earnings (₹)')
                      : pw.Container(),
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
                    // Only show earnings for special day
                    selectedHistoryType == 'special_day'
                        ? _buildPDFTableCell(
                            status == 'successful'
                                ? _getEarningsString(data)
                                : 'N/A',
                            allowWrap: true)
                        : pw.Container(),
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

    // Check for total_scrap_weight field
    if (data['total_scrap_weight'] != null &&
        data['total_scrap_weight'] is num) {
      totalWeight = (data['total_scrap_weight'] as num).toDouble();
      weightStrings.add('Total Scrap: ${totalWeight.toStringAsFixed(2)} kg');
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

  // Add a method to format earnings string for pickups
  String _getEarningsString(Map<String, dynamic> data) {
    // Check for total_scrap_price field
    if (data['total_scrap_price'] != null && data['total_scrap_price'] is num) {
      return '₹${(data['total_scrap_price'] as num).toDouble().toStringAsFixed(2)}';
    }

    // If no total price, calculate from weights and prices
    double totalEarnings = 0.0;
    List<String> earningsStrings = [];

    if (data['scrap_weights'] != null) {
      final weights = data['scrap_weights'] as Map<String, dynamic>;
      weights.forEach((type, weight) {
        if (weight is num) {
          double pricePerKg = scrapPrices[type] ?? 0.0;
          double itemEarnings = weight.toDouble() * pricePerKg;
          totalEarnings += itemEarnings;
          if (pricePerKg > 0) {
            earningsStrings.add(
                '${type.replaceAll('_', ' ')}: ₹${itemEarnings.toStringAsFixed(2)}');
          }
        }
      });
    }

    // If no earnings found
    if (earningsStrings.isEmpty) {
      return totalEarnings > 0 ? '₹${totalEarnings.toStringAsFixed(2)}' : 'N/A';
    }

    // If there are multiple earnings, show total and details
    if (earningsStrings.length > 1) {
      return 'Total: ₹${totalEarnings.toStringAsFixed(2)}\n' +
          earningsStrings.join('\n');
    }

    return earningsStrings.join('\n');
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
    // Initialize ScreenUtil
    ScreenUtil.instance.init(context);

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
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    labelColor: primaryGreen,
                    unselectedLabelColor: Colors.grey,
                    labelStyle: GoogleFonts.poppins(fontSize: 14.sp),
                    unselectedLabelStyle: GoogleFonts.poppins(fontSize: 14.sp),
                    tabs: [
                      Tab(text: 'Successful'),
                      Tab(text: 'Cancelled'),
                    ],
                  ),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: TabBarView(
                      children: [
                        _buildPickupList('successful_pickups'),
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
                  totalEarnings = 0.0; // Don't show earnings for subscription
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
                  totalEarnings = specialDayStats['totalEarnings'];
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
        : specialDayStats;
    final historyType =
        selectedHistoryType == 'subscription' ? 'Subscription' : 'Special Day';

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
                  '${stats["totalWeight"].toStringAsFixed(2)} kg', Icons.scale),
              _buildStatCard(
                  'Carbon Footprint',
                  '${stats["carbonFootprint"].toStringAsFixed(2)} kg CO₂e',
                  Icons.eco),
            ],
          ),
          SizedBox(height: 12.h),
          // Full width earnings container for special day history
          if (selectedHistoryType == 'special_day')
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.w),
              margin: EdgeInsets.only(bottom: 12.h),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Column(
                children: [
                  Icon(Icons.attach_money, color: primaryGreen, size: 24.w),
                  SizedBox(height: 8.h),
                  Text(
                    '₹${stats["totalEarnings"].toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: primaryGreen,
                    ),
                  ),
                  Text(
                    'Total Earnings',
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          // Separate containers for successful and cancelled pickups
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(12.w),
                  margin: EdgeInsets.only(right: 6.w),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 24.w),
                      SizedBox(height: 8.h),
                      Text(
                        stats['successful'].toString(),
                        style: GoogleFonts.poppins(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        'Successful',
                        style: GoogleFonts.poppins(
                          fontSize: 12.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(12.w),
                  margin: EdgeInsets.only(left: 6.w),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.cancel, color: Colors.red, size: 24.w),
                      SizedBox(height: 8.h),
                      Text(
                        stats['cancelled'].toString(),
                        style: GoogleFonts.poppins(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      Text(
                        'Cancelled',
                        style: GoogleFonts.poppins(
                          fontSize: 12.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessfulWithCancelledStat(int successful, int cancelled) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12.w),
        margin: EdgeInsets.symmetric(horizontal: 4.w),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            // Main successful pickups stat
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 24.w),
                  SizedBox(height: 4.h),
                  Text(
                    successful.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Successful',
                    style: GoogleFonts.poppins(
                      fontSize: 12.sp,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            // Vertical divider
            Container(
              height: 40.h,
              width: 1,
              color: Colors.grey[300],
              margin: EdgeInsets.symmetric(horizontal: 4.w),
            ),
            // Smaller cancelled pickups stat
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Icon(Icons.cancel, color: Colors.red, size: 16.w),
                  SizedBox(height: 2.h),
                  Text(
                    cancelled.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Cancelled',
                    style: GoogleFonts.poppins(
                      fontSize: 10.sp,
                      color: Colors.grey[600],
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
            return false; // Scrap history removed
          }
        }).toList();

        if (filteredDocs.isEmpty) {
          return Center(
            child: Text(
              'No ${selectedHistoryType == "subscription" ? "subscription" : "special day"} pickups found',
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
    double totalEarnings = 0.0;

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

          // Calculate earnings if it's a scrap type
          if (scrapPrices.containsKey(type)) {
            double earnings = weight.toDouble() * scrapPrices[type]!;
            totalEarnings += earnings;
          }
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

          // Calculate earnings for scrap items
          double pricePerKg = scrapPrices[type] ?? 0.0;
          double earnings = weight.toDouble() * pricePerKg;
          totalEarnings += earnings;
        }
      });
    }

    // Check for total_scrap_weight field
    if (data['total_scrap_weight'] != null &&
        data['total_scrap_weight'] is num) {
      totalWeight = (data['total_scrap_weight'] as num).toDouble();
      wasteDetails.add(
        Text(
          'Total Scrap Weight: ${totalWeight.toStringAsFixed(2)} kg',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      );
    }

    // For scrap pickups, show total earnings
    if (data['total_scrap_price'] != null && data['total_scrap_price'] is num) {
      totalEarnings = (data['total_scrap_price'] as num).toDouble();
    }

    // Add earnings information if available and only for special day history
    if (totalEarnings > 0 && selectedHistoryType == 'special_day') {
      wasteDetails.add(
        Text(
          'Total Earnings: ₹${totalEarnings.toStringAsFixed(2)}',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.green[700],
          ),
        ),
      );
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

    // Add total weight if multiple waste types and total_scrap_weight not already added
    if (wasteDetails.length > 1 && data['total_scrap_weight'] == null) {
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
