import 'package:flutter/material.dart';

import '../models/report_card.model.dart';

class ReportCardList extends StatelessWidget {
  final List<ReportCard> reportCards;

  const ReportCardList({super.key, required this.reportCards});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
        itemCount: reportCards.length,
        itemBuilder: (context, index) {
          return Text(reportCards[index].when.toString());
        });
  }
}
