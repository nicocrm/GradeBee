import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/report_card.model.dart';
import '../vm/student_details_vm.dart';

class ReportCardDetail extends StatelessWidget {
  final ReportCard reportCard;
  final StudentDetailsVM vm;

  const ReportCardDetail({
    super.key,
    required this.reportCard,
    required this.vm,
  });

  void _showRegenerateDialog(BuildContext context, ReportCard reportCard) {
    showDialog(
      context: context,
      builder: (dialogContext) => _RegenerateDialog(
        reportCard: reportCard,
        vm: vm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('MMMM d, yyyy').format(reportCard.when),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...reportCard.sections.map((section) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.category,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                listenable: Listenable.merge([
                  vm.generateReportCardCommand,
                  vm.regenerateReportCardCommand,
                ]),
                builder: (context, _) {
                  final isRegenerating = vm.regenerateReportCardCommand.running;
                  return ElevatedButton.icon(
                    onPressed: isRegenerating
                        ? null
                        : () => _showRegenerateDialog(context, reportCard),
                    icon: isRegenerating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(isRegenerating ? 'Regenerating...' : 'Regenerate'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegenerateDialog extends StatefulWidget {
  final ReportCard reportCard;
  final StudentDetailsVM vm;

  const _RegenerateDialog({
    required this.reportCard,
    required this.vm,
  });

  @override
  State<_RegenerateDialog> createState() => _RegenerateDialogState();
}

class _RegenerateDialogState extends State<_RegenerateDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Regenerate Report Card'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: 'What would you like to change? (optional)',
          border: OutlineInputBorder(),
          alignLabelWithHint: true,
        ),
        maxLines: 4,
        minLines: 2,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            widget.vm.regenerateReportCardCommand.execute(
                widget.reportCard, _controller.text.trim());
          },
          child: const Text('Regenerate'),
        ),
      ],
    );
  }
}
