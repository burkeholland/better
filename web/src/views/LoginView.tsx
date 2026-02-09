import { useState } from 'react';
import LoadingSpinner from '../components/LoadingSpinner';
import { useAuth } from '../state/AuthContext';

export default function LoginView() {
  const { signIn, error } = useAuth();
  const [isSigningIn, setIsSigningIn] = useState(false);

  const handleSignIn = async () => {
    setIsSigningIn(true);
    try {
      await signIn();
    } finally {
      setIsSigningIn(false);
    }
  };

  return (
    <div className="min-h-screen bg-white text-slate-900">
      <main className="mx-auto flex min-h-screen max-w-lg items-center px-6 py-12">
        <div className="w-full rounded-3xl border border-slate-200 bg-slate-50 px-8 py-10 shadow-sm">
          <div className="text-center">
            <p className="text-xs font-semibold uppercase tracking-[0.3em] text-slate-400">Better</p>
            <h1 className="mt-3 text-3xl font-semibold tracking-tight">Gemini AI Chat</h1>
            <p className="mt-2 text-sm text-slate-500">Sign in to continue your conversations.</p>
          </div>

          <button
            type="button"
            onClick={handleSignIn}
            disabled={isSigningIn}
            className="mt-10 flex w-full items-center justify-center gap-3 rounded-full border border-slate-200 bg-white px-5 py-3 text-sm font-medium text-slate-800 shadow-sm transition hover:bg-slate-100 disabled:cursor-not-allowed disabled:opacity-60"
          >
            {isSigningIn ? (
              <>
                <LoadingSpinner size="sm" />
                <span>Signing in...</span>
              </>
            ) : (
              <span>Continue with Google</span>
            )}
          </button>

          {error ? (
            <p className="mt-4 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
              {error}
            </p>
          ) : null}
        </div>
      </main>
    </div>
  );
}
