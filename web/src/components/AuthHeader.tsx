import { useAuth } from '@/lib/auth';

export default function AuthHeader() {
  const { user, logout } = useAuth();

  if (!user) return null;

  return (
    <div className="flex items-center gap-3 text-sm">
      <span className="text-[var(--color-text-muted)]">{user.email}</span>
      <button
        onClick={logout}
        className="cursor-pointer rounded-lg px-3 py-1 text-[var(--color-text-muted)] transition-colors hover:bg-gray-100 hover:text-[var(--color-text)]"
      >
        Logout
      </button>
    </div>
  );
}
