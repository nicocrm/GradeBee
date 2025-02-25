import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/report_card.model.dart';
import '../vm/student_details_vm.dart';

class ReportCardList extends StatelessWidget {
  final List<ReportCard> reportCards;
  final StudentDetailsVM vm;

  const ReportCardList(
      {super.key, required this.reportCards, required this.vm});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: reportCards.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final reportCard = reportCards[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date heading
                Text(
                  DateFormat('MMMM d, yyyy').format(reportCard.when),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                // Sections
                ...reportCard.sections.map((section) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.category,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: Text(section.text)),
                            IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: () {
                                Clipboard.setData(
                                    ClipboardData(text: section.text));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Copied to clipboard'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    )),
                const SizedBox(height: 16),
                Center(
                  child: ListenableBuilder(
                    listenable: vm.generateReportCardCommand,
                    builder: (context, _) {
                      return ElevatedButton.icon(
                        onPressed: vm.generateReportCardCommand.running
                            ? null
                            : () async => await vm.generateReportCardCommand
                                .execute(reportCard),
                        icon: vm.generateReportCardCommand.running
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh),
                        label: Text(vm.generateReportCardCommand.running
                            ? 'Regenerating...'
                            : 'Regenerate'),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
