import 'package:dotenv/dotenv.dart';
import 'package:gradebee_models/common.dart';
import 'package:split_notes_by_student/note_splitter.dart';
import 'package:test/test.dart';

void main() {
  group('Note Splitter', () {
    final env = DotEnv()..load(["../../.env"]);
    final noteSplitter = NoteSplitter(env['OPENAI_API_KEY']!);

    test('if student name is not found, it should be ignored', () async {
      final note = Note(
        id: '1',
        when: DateTime.now(),
        class_: Class(id: '1', students: [
          Student(id: '1', name: 'John'),
        ]),
        text: 'This is a test note',
      );
      final studentNotes =
          await noteSplitter.splitNotesByStudent(note).toList();
      expect(studentNotes.length, 0);
    });

    test('if student name is not mentioned in the list, it should be ignored',
        () async {
      final note = Note(
        id: '1',
        when: DateTime.now(),
        class_: Class(id: '1', students: [Student(id: '1', name: 'John')]),
        text: 'Lily was great today',
      );
      final studentNotes =
          await noteSplitter.splitNotesByStudent(note).toList();
      expect(studentNotes.length, 0);
    });

    test('if student name is found, it should be included', () async {
      final note = Note(
        id: '1',
        when: DateTime.now(),
        class_: Class(id: '1', students: [Student(id: '1', name: 'John')]),
        text: 'John was great today',
      );
      final studentNotes =
          await noteSplitter.splitNotesByStudent(note).toList();
      expect(studentNotes.length, 1);
      expect(studentNotes.first.student.name, 'John');
      // Use approximate matching - check that the text contains the key information
      expect(studentNotes.first.text.toLowerCase(), contains('john was great today'));
    });

    test(
        'when multiple students are included in the note, they should all be included',
        () async {
      final note = Note(
        id: '1',
        when: DateTime.now(),
        class_: Class(id: '1', students: [
          Student(id: '1', name: 'Oliver'),
          Student(id: '2', name: 'Emma'),
          Student(id: '3', name: 'Lucas'),
          Student(id: '4', name: 'Liam'),
        ]),
        text: '''
Today’s class went well overall. Oliver was very engaged during the group discussion and asked thoughtful questions about the homework. However, he’s still struggling a bit with subject-verb agreement in his writing, so I’ll need to provide him with some extra practice on that. Emma continues to be a strong student; she completed all her tasks quickly and with accuracy. That said, she’s still hesitant to speak up in class, so I’ll need to find ways to build her confidence during discussions. Lucas showed great creativity during the free writing activity, though he veered off-topic and needed some redirection. His reading fluency is improving, but unfamiliar words still trip him up occasionally. He worked really well with Sophia during their partner activity. Speaking of Sophia, she was fantastic at giving feedback during peer reviews, but her writing could use more varied vocabulary since she tends to repeat the same descriptive words. Liam had a slow start today and was a little distracted early on, but he made some insightful contributions during the persuasive writing discussion. His handwriting needs improvement; it’s often difficult to read. Next class, I’ll focus on speaking exercises and vocabulary building to support their growth.
''',
      );
      final studentNotes =
          await noteSplitter.splitNotesByStudent(note).toList();
      expect(studentNotes.length, 4);
      expect(studentNotes.first.student.name, 'Oliver');
      // Use approximate matching for Oliver's note - check key concepts are present
      final oliverNote = studentNotes.first.text.toLowerCase();
      expect(oliverNote, contains('oliver'));
      expect(oliverNote, contains('engaged'));
      expect(oliverNote, contains('discussion'));
      expect(oliverNote, contains('subject-verb agreement'));
      expect(studentNotes.any((note) => note.student.name == 'Sophia'), false,
          reason:
              'As Sophia\'s name was not given in the student list, it should not be included in the results');
      expect(studentNotes.map((note) => note.student.name),
          ['Oliver', 'Emma', 'Lucas', 'Liam']);
    });
  });
}
