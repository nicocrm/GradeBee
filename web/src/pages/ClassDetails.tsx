import { useParams } from 'react-router';

export default function ClassDetails() {
  const { classId } = useParams();

  return (
    <div className="p-6">
      <h1 className="text-2xl font-bold">Class Details</h1>
      <p className="mt-2 text-[var(--color-text-muted)]">Class ID: {classId}</p>
    </div>
  );
}
