import 'package:flutter/material.dart';
import '../../../shared/ui/utils/error_mixin.dart';
import '../models/report_card.model.dart';
import '../vm/student_details_vm.dart';
import 'report_card_detail.dart';

class ReportCardList extends StatefulWidget {
  final List<ReportCard> reportCards;
  final StudentDetailsVM vm;

  const ReportCardList(
      {super.key, required this.reportCards, required this.vm});

  @override
  State<ReportCardList> createState() => _ReportCardListState();
}

class _ReportCardListState extends State<ReportCardList> with ErrorMixin {
  @override
  void initState() {
    super.initState();
    widget.vm.generateReportCardCommand.addListener(_handleCommandUpdate);
    widget.vm.addReportCardCommand.addListener(_handleCommandUpdate);
  }

  @override
  void dispose() {
    widget.vm.generateReportCardCommand.removeListener(_handleCommandUpdate);
    widget.vm.addReportCardCommand.removeListener(_handleCommandUpdate);
    super.dispose();
  }

  void _handleCommandUpdate() {
    final generateCommand = widget.vm.generateReportCardCommand;
    if (generateCommand.error != null) {
      showErrorSnackbar(generateCommand.error!.error.toString());
    } else if (!generateCommand.running && generateCommand.value != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report card generated successfully'),
        ),
      );
    }
    generateCommand.clearResult();
    final addCommand = widget.vm.addReportCardCommand;
    if (addCommand.error != null) {
      showErrorSnackbar(addCommand.error!.error.toString());
    } else if (!addCommand.running && addCommand.value != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report card added successfully'),
        ),
      );
    }
    addCommand.clearResult();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 80,
          ),
          itemCount: widget.reportCards.length,
          itemBuilder: (context, index) {
            final reportCard = widget.reportCards[index];
            return ReportCardDetail(
              reportCard: reportCard,
              vm: widget.vm,
            );
          },
        ),
        Positioned(
          right: 0,
          left: 0,
          bottom: 16,
          child: Center(
            child: ListenableBuilder(
              listenable: widget.vm.addReportCardCommand,
              builder: (context, _) => FloatingActionButton.extended(
                onPressed: widget.vm.addReportCardCommand.running
                    ? null
                    : () => _showCreateReportCardDialog(context),
                label: widget.vm.addReportCardCommand.running
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(),
                      )
                    : const Text('Add Report Card'),
                icon: widget.vm.addReportCardCommand.running
                    ? null
                    : const Icon(Icons.add),
              ),
            ),
          ),
        )
      ],
    );
  }

  void _showCreateReportCardDialog(BuildContext context) async {
    final now = DateTime.now();
    DateTime startDate = now.subtract(const Duration(days: 90));
    DateTime endDate = now;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Report Card'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Start Date'),
              subtitle: Text(
                '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}',
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: now.add(const Duration(days: 365)),
                  initialDate: startDate,
                );
                if (picked != null && context.mounted) {
                  startDate = picked;
                  Navigator.pop(context);
                  _showCreateReportCardDialog(context);
                }
              },
            ),
            ListTile(
              title: const Text('End Date'),
              subtitle: Text(
                '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}',
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  firstDate: startDate,
                  lastDate: now.add(const Duration(days: 365)),
                  initialDate: endDate,
                );
                if (picked != null && context.mounted) {
                  endDate = picked;
                  Navigator.pop(context);
                  _showCreateReportCardDialog(context);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.vm.addReportCardCommand.execute(DateTimeRange(
                start: startDate,
                end: endDate,
              ));
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
