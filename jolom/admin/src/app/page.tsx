"use client";

import type { CSSProperties, FormEvent } from "react";
import { useEffect, useState } from "react";
import {
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
  User,
} from "firebase/auth";
import {
  collection,
  getDocs,
  limit,
  orderBy,
  query,
  where,
} from "firebase/firestore";
import { callApplyModeration, getClientAuth, getClientDb } from "@/lib/firebase";

type ReportRow = {
  id: string;
  targetType?: string;
  targetId?: string;
  category?: string;
  description?: string;
  status?: string;
  reporterId?: string;
};

export default function AdminPage() {
  const [user, setUser] = useState<User | null>(null);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [reports, setReports] = useState<ReportRow[]>([]);
  const [loading, setLoading] = useState(false);
  const [actionBusy, setActionBusy] = useState<string | null>(null);

  useEffect(() => {
    return onAuthStateChanged(getClientAuth(), async (u) => {
      setUser(u);
      if (u) {
        const token = await u.getIdTokenResult(true);
        if (token.claims.role !== "admin") {
          setError("Esta cuenta no tiene rol administrador.");
          await signOut(getClientAuth());
          setUser(null);
          return;
        }
        await loadReports();
      }
    });
  }, []);

  async function loadReports() {
    setLoading(true);
    setError(null);
    try {
      const q = query(
        collection(getClientDb(), "reports"),
        orderBy("createdAt", "desc"),
        limit(50),
      );
      const snap = await getDocs(q);
      setReports(
        snap.docs.map((d) => ({
          id: d.id,
          ...(d.data() as object),
        })) as ReportRow[],
      );
    } catch (e) {
      setError(e instanceof Error ? e.message : "Error al cargar reportes");
    } finally {
      setLoading(false);
    }
  }

  async function onLogin(e: FormEvent) {
    e.preventDefault();
    setError(null);
    try {
      await signInWithEmailAndPassword(getClientAuth(), email, password);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Login fallido");
    }
  }

  async function moderate(report: ReportRow, action: string) {
    if (!report.targetType || !report.targetId) return;
    setActionBusy(report.id);
    setError(null);
    try {
      await callApplyModeration({
        targetType: report.targetType,
        targetId: report.targetId,
        action,
        reason: `Desde reporte ${report.id}: ${report.category || "n/a"}`,
        reportId: report.id,
      });
      await loadReports();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Acción fallida");
    } finally {
      setActionBusy(null);
    }
  }

  async function loadOpenOnly() {
    setLoading(true);
    try {
      const q = query(
        collection(getClientDb(), "reports"),
        where("status", "in", ["received", "inReview"]),
        orderBy("createdAt", "desc"),
        limit(50),
      );
      const snap = await getDocs(q);
      setReports(
        snap.docs.map((d) => ({
          id: d.id,
          ...(d.data() as object),
        })) as ReportRow[],
      );
    } catch (e) {
      await loadReports();
      setError(e instanceof Error ? e.message : "Filtro no disponible");
    } finally {
      setLoading(false);
    }
  }

  if (!user) {
    return (
      <main style={styles.main}>
        <h1 style={styles.h1}>Jolom Moderación</h1>
        <p>
          Dashboard privado. Solo cuentas con claim <code>role=admin</code>.
        </p>
        <form onSubmit={onLogin} style={styles.card}>
          <label>
            Email
            <input
              style={styles.input}
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              type="email"
              required
            />
          </label>
          <label>
            Contraseña
            <input
              style={styles.input}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              type="password"
              required
            />
          </label>
          {error && <p style={styles.error}>{error}</p>}
          <button style={styles.button} type="submit">
            Entrar
          </button>
        </form>
      </main>
    );
  }

  return (
    <main style={styles.main}>
      <header style={styles.header}>
        <div>
          <h1 style={styles.h1}>Reportes y moderación</h1>
          <p>{user.email}</p>
        </div>
        <div style={{ display: "flex", gap: 8 }}>
          <button style={styles.secondary} onClick={loadReports} type="button">
            Recargar
          </button>
          <button style={styles.secondary} onClick={loadOpenOnly} type="button">
            Abiertos
          </button>
          <button
            style={styles.secondary}
            onClick={() => signOut(getClientAuth())}
            type="button"
          >
            Salir
          </button>
        </div>
      </header>

      {error && <p style={styles.error}>{error}</p>}
      {loading && <p>Cargando…</p>}

      <section style={styles.grid}>
        {reports.map((r) => (
          <article key={r.id} style={styles.card}>
            <strong>{r.category || "Sin categoría"}</strong>
            <div style={styles.meta}>
              {r.targetType}/{r.targetId} · {r.status}
            </div>
            <p>{r.description}</p>
            <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
              <button
                style={styles.button}
                disabled={actionBusy === r.id}
                onClick={() => moderate(r, "warn")}
                type="button"
              >
                Advertir
              </button>
              <button
                style={styles.button}
                disabled={actionBusy === r.id}
                onClick={() => moderate(r, "suspend")}
                type="button"
              >
                Suspender
              </button>
              <button
                style={styles.button}
                disabled={actionBusy === r.id}
                onClick={() => moderate(r, "ban")}
                type="button"
              >
                Banear
              </button>
              <button
                style={styles.secondary}
                disabled={actionBusy === r.id}
                onClick={() => moderate(r, "unpublish")}
                type="button"
              >
                Despublicar
              </button>
              <button
                style={styles.secondary}
                disabled={actionBusy === r.id}
                onClick={() => moderate(r, "softDelete")}
                type="button"
              >
                Soft delete
              </button>
              <button
                style={styles.secondary}
                disabled={actionBusy === r.id}
                onClick={() => moderate(r, "restore")}
                type="button"
              >
                Restaurar
              </button>
            </div>
          </article>
        ))}
      </section>
    </main>
  );
}

const styles: Record<string, CSSProperties> = {
  main: {
    maxWidth: 960,
    margin: "0 auto",
    padding: "32px 20px 64px",
    fontFamily: "ui-sans-serif, system-ui, sans-serif",
    background: "linear-gradient(180deg, #f7f4ef 0%, #fff 40%)",
    minHeight: "100vh",
  },
  h1: { margin: 0, fontSize: 28 },
  header: {
    display: "flex",
    justifyContent: "space-between",
    gap: 16,
    alignItems: "flex-start",
    marginBottom: 24,
  },
  card: {
    background: "#fff",
    border: "1px solid #e7e1d8",
    borderRadius: 12,
    padding: 16,
    display: "grid",
    gap: 10,
  },
  grid: { display: "grid", gap: 12 },
  input: {
    display: "block",
    width: "100%",
    marginTop: 4,
    padding: "10px 12px",
    borderRadius: 8,
    border: "1px solid #ccc",
  },
  button: {
    background: "#1f3b2c",
    color: "#fff",
    border: 0,
    borderRadius: 8,
    padding: "8px 12px",
    cursor: "pointer",
  },
  secondary: {
    background: "#f0ebe3",
    color: "#222",
    border: "1px solid #d9d0c4",
    borderRadius: 8,
    padding: "8px 12px",
    cursor: "pointer",
  },
  error: { color: "#9b1c1c" },
  meta: { color: "#666", fontSize: 13 },
};
