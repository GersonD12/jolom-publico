"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import {
  GoogleAuthProvider,
  onAuthStateChanged,
  signInWithPopup,
  signOut as firebaseSignOut,
  type User,
} from "firebase/auth";
import { getClientAuth } from "@/lib/firebase/client";
import type { SessionUser } from "@/types/session";

type AuthState = {
  user: SessionUser | null;
  firebaseUser: User | null;
  loading: boolean;
  error: string | null;
  signInWithGoogle: () => Promise<void>;
  signOut: () => Promise<void>;
  clearError: () => void;
};

const AuthContext = createContext<AuthState | null>(null);

async function toSessionUser(user: User): Promise<SessionUser | null> {
  const token = await user.getIdTokenResult(true);
  if (token.claims.role !== "admin") {
    return null;
  }
  return {
    id: user.uid,
    email: user.email ?? "",
    name: user.displayName ?? undefined,
    photoUrl: user.photoURL ?? undefined,
    role: "admin",
  };
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [firebaseUser, setFirebaseUser] = useState<User | null>(null);
  const [user, setUser] = useState<SessionUser | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const auth = getClientAuth();
    return onAuthStateChanged(auth, async (u) => {
      setLoading(true);
      setError(null);
      if (!u) {
        setFirebaseUser(null);
        setUser(null);
        setLoading(false);
        return;
      }
      try {
        const session = await toSessionUser(u);
        if (!session) {
          setError(
            "Esta cuenta no tiene rol administrador. Solicita el claim role=admin.",
          );
          await firebaseSignOut(auth);
          setFirebaseUser(null);
          setUser(null);
        } else {
          setFirebaseUser(u);
          setUser(session);
        }
      } catch (e) {
        setError(e instanceof Error ? e.message : "Error de autenticación");
        setFirebaseUser(null);
        setUser(null);
      } finally {
        setLoading(false);
      }
    });
  }, []);

  const signInWithGoogle = useCallback(async () => {
    setError(null);
    const auth = getClientAuth();
    const provider = new GoogleAuthProvider();
    provider.setCustomParameters({ prompt: "select_account" });
    try {
      const result = await signInWithPopup(auth, provider);
      const session = await toSessionUser(result.user);
      if (!session) {
        setError(
          "Esta cuenta no tiene rol administrador. Solicita el claim role=admin.",
        );
        await firebaseSignOut(auth);
        setFirebaseUser(null);
        setUser(null);
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : "No se pudo iniciar sesión");
    }
  }, []);

  const signOut = useCallback(async () => {
    await firebaseSignOut(getClientAuth());
    setUser(null);
    setFirebaseUser(null);
  }, []);

  const clearError = useCallback(() => setError(null), []);

  const value = useMemo(
    () => ({
      user,
      firebaseUser,
      loading,
      error,
      signInWithGoogle,
      signOut,
      clearError,
    }),
    [
      user,
      firebaseUser,
      loading,
      error,
      signInWithGoogle,
      signOut,
      clearError,
    ],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) {
    throw new Error("useAuth debe usarse dentro de AuthProvider");
  }
  return ctx;
}
