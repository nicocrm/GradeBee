import 'package:flutter/material.dart';
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

class _ReportCardListState extends State<ReportCardList> {
  @override
  void initState() {
    super.initState();
    widget.vm.generateReportCardCommand.addListener(_handleCommandUpdate);
  }

  @override
  void dispose() {
    widget.vm.generateReportCardCommand.removeListener(_handleCommandUpdate);
    super.dispose();
  }

  void _handleCommandUpdate() {
    final command = widget.vm.generateReportCardCommand;
    if (command.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(command.error!.error.toString()),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } else if (!command.running && command.value != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report card regenerated successfully'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: widget.reportCards.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        return ReportCardDetail(
          reportCard: widget.reportCards[index],
          vm: widget.vm,
        );
      },
    );
  }
}
