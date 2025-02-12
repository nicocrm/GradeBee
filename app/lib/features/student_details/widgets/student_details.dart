import 'package:flutter/material.dart';

import '../models/student.model.dart';
import 'report_card_list.dart';
import 'notes_list.dart';

class StudentDetails extends StatelessWidget {
  final Student student;

  const StudentDetails({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Notes'),
              Tab(text: 'Report Card'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Notes Tab
                _NotesTab(student: student),

                // Report Card Tab
                _ReportCardTab(student: student),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// class _DetailsTab extends StatelessWidget {
//   final Student student;

//   const _DetailsTab({required this.student});

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Text(student.name),
//         // Add more student details here
//       ],
//     );
//   }
// }

class _NotesTab extends StatelessWidget {
  final Student student;

  const _NotesTab({required this.student});

  @override
  Widget build(BuildContext context) {
    return NotesList(
      notes: student.notes,
    );
  }
}

class _ReportCardTab extends StatelessWidget {
  final Student student;

  const _ReportCardTab({required this.student});

  @override
  Widget build(BuildContext context) {
    return ReportCardList(
      reportCards: student.reportCards,
    );
  }
}
