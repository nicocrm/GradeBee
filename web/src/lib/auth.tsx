import { createContext, useContext, useState, useEffect, useCallback, type ReactNode } from 'react';
import { OAuthProvider, type Models } from 'appwrite';
import { account } from '@/lib/appwrite';

interface AuthContextValue {
  user: Models.User<Models.Preferences> | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  login: (email: string, password: string) => Promise<void>;
  loginWithGoogle: () => Promise<void>;
  logout: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<Models.User<Models.Preferences> | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    account.get()
      .then(setUser)
      .catch(() => setUser(null))
      .finally(() => setIsLoading(false));
  }, []);

  const login = useCallback(async (email: string, password: string) => {
    await account.createEmailPasswordSession(email, password);
    const u = await account.get();
    setUser(u);
  }, []);

  const loginWithGoogle = useCallback(async () => {
    account.createOAuth2Session(
      OAuthProvider.Google,
      window.location.origin + '/',
      window.location.origin + '/login',
    );
  }, []);

  const logout = useCallback(async () => {
    await account.deleteSessions();
    setUser(null);
  }, []);

  return (
    <AuthContext value={{
      user,
      isAuthenticated: !!user,
      isLoading,
      login,
      loginWithGoogle,
      logout,
    }}>
      {children}
    </AuthContext>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) throw new Error('useAuth must be used within AuthProvider');
  return context;
}
