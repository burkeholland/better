import { GoogleAuthProvider, signInWithPopup, signOut as firebaseSignOut, type User } from 'firebase/auth';
import type { FirebaseError } from 'firebase/app';
import { auth } from './config';

const provider = new GoogleAuthProvider();
provider.setCustomParameters({ prompt: 'select_account' });

const getAuthErrorMessage = (error: unknown, action: 'sign-in' | 'sign-out'): string => {
  const fallback =
    action === 'sign-in'
      ? 'Unable to sign in right now. Please try again.'
      : 'Unable to sign out right now. Please try again.';

  const code = (error as FirebaseError | { code?: string })?.code;

  switch (code) {
    case 'auth/popup-closed-by-user':
      return 'Sign-in was closed before it finished.';
    case 'auth/cancelled-popup-request':
      return 'Another sign-in request is already in progress.';
    case 'auth/popup-blocked':
      return 'The sign-in popup was blocked. Please allow popups and try again.';
    case 'auth/network-request-failed':
      return 'Network error. Check your connection and try again.';
    case 'auth/user-disabled':
      return 'This account has been disabled.';
    case 'auth/too-many-requests':
      return 'Too many attempts. Please wait a moment and try again.';
    case 'auth/account-exists-with-different-credential':
      return 'This account already exists with a different sign-in method.';
    case 'auth/operation-not-allowed':
      return 'Google sign-in is not enabled for this project.';
    default:
      return fallback;
  }
};

export const signInWithGoogle = async (): Promise<User> => {
  try {
    const result = await signInWithPopup(auth, provider);
    return result.user;
  } catch (error) {
    throw new Error(getAuthErrorMessage(error, 'sign-in'));
  }
};

export const signOut = async (): Promise<void> => {
  try {
    await firebaseSignOut(auth);
  } catch (error) {
    throw new Error(getAuthErrorMessage(error, 'sign-out'));
  }
};
