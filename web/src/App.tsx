import React from 'react';
import LoadingSpinner from './components/LoadingSpinner';
import { AuthProvider, useAuth } from './state/AuthContext';
import { ConversationStoreProvider } from './state/ConversationStore';
import LoginView from './views/LoginView';
import ChatView from './views/ChatView';

function AppContent() {
  const { user, loading } = useAuth();

  if (loading) {
    return (
      <div className="min-h-screen bg-white text-slate-900 flex items-center justify-center">
          <LoadingSpinner label="Loading your session..." />
      </div>
    );
  }

  if (!user) {
    // For demo purposes, if you want to bypass login locally you could return <ChatView /> here temporarily.
    // Keeping logic:
    return <LoginView />;
  }

  return <ChatView />;
}

export default function App() {
  return (
    <AuthProvider>
      <ConversationStoreProvider>
        <AppContent />
      </ConversationStoreProvider>
    </AuthProvider>
  );
}
