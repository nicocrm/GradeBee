import { Outlet, Link } from 'react-router';
import AuthHeader from '@/components/AuthHeader';

export default function PageLayout() {
  return (
    <div className="min-h-screen">
      <header className="border-b border-[var(--color-border)] bg-[var(--color-surface)] px-6 py-3">
        <div className="flex items-center justify-between">
          <Link to="/" className="text-xl font-bold text-[var(--color-primary-dark)]">
            GradeBee
          </Link>
          <AuthHeader />
        </div>
      </header>
      <main>
        <Outlet />
      </main>
    </div>
  );
}
