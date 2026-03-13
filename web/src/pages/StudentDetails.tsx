import { useParams } from 'react-router';

export default function StudentDetails() {
  const { classId, studentId } = useParams();

  return (
    <div className="p-6">
      <h1 className="text-2xl font-bold">Student Details</h1>
      <p className="mt-2 text-[var(--color-text-muted)]">
        Class: {classId} / Student: {studentId}
      </p>
    </div>
  );
}
