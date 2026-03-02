import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/db_service.dart';
import '../theme/app_theme.dart';

pw.Widget _buildPdfTicketField(String label, String value) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(
        label,
        style: pw.TextStyle(
          fontSize: 14,
          color: PdfColors.grey700,
        ),
      ),
      pw.Text(
        value,
        style: pw.TextStyle(
          fontSize: 16,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    ],
  );
}

class ReservationConfirmationScreen extends StatelessWidget {
  static const routeName = '/reservation';

  const ReservationConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final ticketId = args?['ticketId'] as String?;

    if (ticketId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Confirmation')),
        body: const Center(child: Text('Ticket not found')),
      );
    }

    final db = context.read<DbService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Ticket Confirmation')),
      body: FutureBuilder(
        future: db.getTicketDetails(ticketId),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Failed to load ticket'),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.popUntil(
                      context,
                      ModalRoute.withName('/events'),
                    ),
                    child: const Text('Back to Events'),
                  ),
                ],
              ),
            );
          }

          final ticketData = snapshot.data!;
          final ticketNumber = ticketData['ticketId']?.toString() ?? 'TKT-unknown';
          final reservedAt = ticketData['reservedAt']?.toDate();
          final status = ticketData['status'] ?? 'reserved';
          final seatLabel = ticketData['seatLabel']?.toString();
          final price = ticketData['price']?.toString();

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  // Success Icon
                  Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.successColor.withAlpha((0.1 * 255).round()),
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        size: 60,
                        color: AppTheme.successColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Success Message
                  const Center(
                    child: Text(
                      'Ticket Reserved Successfully!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.successColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'Your ticket has been secured.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Ticket Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryColor, AppTheme.accentColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ticket Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildTicketField(
                          label: 'Ticket Number',
                          value: ticketNumber,
                        ),
                        const SizedBox(height: 16),
                        _buildTicketField(
                          label: 'Status',
                          value: status.toUpperCase(),
                        ),
                        const SizedBox(height: 16),
                        if (seatLabel != null)
                          _buildTicketField(
                            label: 'Seat',
                            value: seatLabel,
                          ),
                        if (seatLabel != null) const SizedBox(height: 16),
                        if (price != null)
                          _buildTicketField(
                            label: 'Price',
                            value: '฿$price',
                          ),
                        if (price != null) const SizedBox(height: 16),
                        _buildTicketField(
                          label: 'Reserved At',
                          value: reservedAt != null
                              ? '${reservedAt.day}/${reservedAt.month}/${reservedAt.year} ${reservedAt.hour}:${reservedAt.minute.toString().padLeft(2, '0')}'
                              : 'N/A',
                        ),
                        const SizedBox(height: 16),
                        _buildTicketField(
                          label: 'Ticket Type',
                          value: 'General Admission',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Important Notice
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withAlpha((0.1 * 255).round()),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info, color: Colors.blue),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Important',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Please save your ticket number. You will need it to check in at the event. One ticket per account per event.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        final pdf = pw.Document();

                        pdf.addPage(
                          pw.Page(
                            pageFormat: PdfPageFormat.a4,
                            build: (pw.Context context) {
                              return pw.Container(
                                padding: const pw.EdgeInsets.all(24),
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text(
                                      'Ticket Details',
                                      style: pw.TextStyle(
                                        fontSize: 24,
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                    pw.SizedBox(height: 24),
                                    _buildPdfTicketField('Ticket Number', ticketNumber),
                                    pw.SizedBox(height: 16),
                                    _buildPdfTicketField('Status', status.toUpperCase()),
                                    if (seatLabel != null) ...[
                                      pw.SizedBox(height: 16),
                                      _buildPdfTicketField('Seat', seatLabel),
                                    ],
                                    if (price != null) ...[
                                      pw.SizedBox(height: 16),
                                      _buildPdfTicketField('Price', 'THB $price'),
                                    ],
                                    pw.SizedBox(height: 16),
                                    _buildPdfTicketField(
                                      'Reserved At',
                                      reservedAt != null
                                          ? '${reservedAt.day}/${reservedAt.month}/${reservedAt.year} ${reservedAt.hour}:${reservedAt.minute.toString().padLeft(2, '0')}'
                                          : 'N/A',
                                    ),
                                    pw.SizedBox(height: 16),
                                    _buildPdfTicketField('Ticket Type', 'General Admission'),
                                  ],
                                ),
                              );
                            },
                          ),
                        );

                        await Printing.layoutPdf(
                          onLayout: (PdfPageFormat format) async => pdf.save(),
                        );
                      } catch (e) {
                         ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(
                             content: Text('Error generating PDF: $e'),
                           ),
                         );
                      }
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Download Ticket'),
                  ),
                  const SizedBox(height: 32),
                  // Back Button
                  ElevatedButton(
                    onPressed: () => Navigator.pushReplacementNamed(
                      context,
                      '/events',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade300,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Back to Events'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTicketField({
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
