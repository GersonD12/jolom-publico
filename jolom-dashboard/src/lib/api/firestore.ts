import {
  collection,
  doc,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  addDoc,
  where,
  type DocumentData,
  type QueryConstraint,
} from "firebase/firestore";
import { getClientAuth, getClientDb } from "@/lib/firebase/client";
import type {
  AppConfigSettingsDoc,
  AppPlatformUpdateConfig,
  AppUpdateConfig,
  AuditLogDoc,
  AccountDeletionJobDoc,
  BarberProfileDoc,
  ModerationCaseDoc,
  ReportDoc,
  SalonDoc,
  SalonMembershipDoc,
  ServiceDoc,
  UserDoc,
} from "@/types/firestore";

export type WithId<T> = T & { id: string };

function mapDocs<T>(snap: { docs: Array<{ id: string; data: () => DocumentData }> }): WithId<T>[] {
  return snap.docs.map((d) => ({ id: d.id, ...(d.data() as T) }));
}

export async function listReports(options?: {
  openOnly?: boolean;
  max?: number;
}): Promise<WithId<ReportDoc>[]> {
  const max = options?.max ?? 50;
  try {
    const constraints: QueryConstraint[] = [];
    if (options?.openOnly) {
      constraints.push(where("status", "in", ["received", "inReview"]));
    }
    constraints.push(orderBy("createdAt", "desc"), limit(max));
    const q = query(collection(getClientDb(), "reports"), ...constraints);
    return mapDocs<ReportDoc>(await getDocs(q));
  } catch {
    const q = query(
      collection(getClientDb(), "reports"),
      orderBy("createdAt", "desc"),
      limit(max),
    );
    const rows = mapDocs<ReportDoc>(await getDocs(q));
    if (options?.openOnly) {
      return rows.filter(
        (r) => r.status === "received" || r.status === "inReview",
      );
    }
    return rows;
  }
}

export async function getReport(
  id: string,
): Promise<WithId<ReportDoc> | null> {
  const snap = await getDoc(doc(getClientDb(), "reports", id));
  if (!snap.exists()) return null;
  return { id: snap.id, ...(snap.data() as ReportDoc) };
}

export async function listModerationCases(max = 50): Promise<WithId<ModerationCaseDoc>[]> {
  const q = query(
    collection(getClientDb(), "moderationCases"),
    orderBy("createdAt", "desc"),
    limit(max),
  );
  return mapDocs<ModerationCaseDoc>(await getDocs(q));
}

export async function listUsers(max = 80): Promise<WithId<UserDoc>[]> {
  const q = query(
    collection(getClientDb(), "users"),
    orderBy("createdAt", "desc"),
    limit(max),
  );
  try {
    return mapDocs<UserDoc>(await getDocs(q));
  } catch {
    return mapDocs<UserDoc>(await getDocs(collection(getClientDb(), "users")));
  }
}

export async function getUser(id: string): Promise<WithId<UserDoc> | null> {
  const snap = await getDoc(doc(getClientDb(), "users", id));
  if (!snap.exists()) return null;
  return { id: snap.id, ...(snap.data() as UserDoc) };
}

export async function getBarberProfile(
  id: string,
): Promise<WithId<BarberProfileDoc> | null> {
  const snap = await getDoc(doc(getClientDb(), "barberProfiles", id));
  if (!snap.exists()) return null;
  return { id: snap.id, ...(snap.data() as BarberProfileDoc) };
}

export async function getMembership(
  uid: string,
): Promise<WithId<SalonMembershipDoc> | null> {
  const snap = await getDoc(doc(getClientDb(), "salonMemberships", uid));
  if (!snap.exists()) return null;
  return { id: snap.id, ...(snap.data() as SalonMembershipDoc) };
}

export async function listSalons(max = 80): Promise<WithId<SalonDoc>[]> {
  try {
    const q = query(
      collection(getClientDb(), "salons"),
      orderBy("createdAt", "desc"),
      limit(max),
    );
    return mapDocs<SalonDoc>(await getDocs(q));
  } catch {
    return mapDocs<SalonDoc>(await getDocs(collection(getClientDb(), "salons")));
  }
}

export async function getSalon(id: string): Promise<WithId<SalonDoc> | null> {
  const snap = await getDoc(doc(getClientDb(), "salons", id));
  if (!snap.exists()) return null;
  return { id: snap.id, ...(snap.data() as SalonDoc) };
}

export async function listSalonMemberships(
  salonId: string,
): Promise<WithId<SalonMembershipDoc>[]> {
  try {
    const q = query(
      collection(getClientDb(), "salonMemberships"),
      where("salonId", "==", salonId),
    );
    return mapDocs<SalonMembershipDoc>(await getDocs(q));
  } catch {
    return [];
  }
}

export async function listSalonServices(
  salonId: string,
): Promise<WithId<ServiceDoc>[]> {
  try {
    const q = query(
      collection(getClientDb(), "services"),
      where("salonId", "==", salonId),
      limit(40),
    );
    return mapDocs<ServiceDoc>(await getDocs(q));
  } catch {
    return [];
  }
}

export async function listReportsForTarget(
  targetId: string,
): Promise<WithId<ReportDoc>[]> {
  try {
    const q = query(
      collection(getClientDb(), "reports"),
      where("targetId", "==", targetId),
      orderBy("createdAt", "desc"),
      limit(20),
    );
    return mapDocs<ReportDoc>(await getDocs(q));
  } catch {
    const all = await listReports({ max: 100 });
    return all.filter((r) => r.targetId === targetId);
  }
}

export async function listAuditLogs(max = 80): Promise<WithId<AuditLogDoc>[]> {
  const q = query(
    collection(getClientDb(), "auditLogs"),
    orderBy("createdAt", "desc"),
    limit(max),
  );
  return mapDocs<AuditLogDoc>(await getDocs(q));
}

export async function listDeletedUsers(): Promise<WithId<UserDoc>[]> {
  const users = await listUsers(200);
  return users.filter(
    (u) => u.isDeleted || Boolean(u.deletionRequestedAt) || u.isBanned,
  );
}

export async function listDeletedSalons(): Promise<WithId<SalonDoc>[]> {
  const salons = await listSalons(200);
  const byId = new Map<string, WithId<SalonDoc>>();
  for (const s of salons) {
    if (
      s.isDeleted ||
      s.publishStatus === "deleted" ||
      s.publishStatus === "suspended"
    ) {
      byId.set(s.id, s);
    }
  }
  try {
    const q = query(
      collection(getClientDb(), "salons"),
      where("isDeleted", "==", true),
      limit(50),
    );
    for (const s of mapDocs<SalonDoc>(await getDocs(q))) {
      byId.set(s.id, s);
    }
  } catch {
    // Fallback already covered by listSalons filter above.
  }
  return Array.from(byId.values());
}

export async function listDeletionRequestCases(): Promise<
  WithId<ModerationCaseDoc>[]
> {
  const cases = await listModerationCases(100);
  return cases.filter((c) => c.action === "accountDeletionRequest");
}

export async function listAccountDeletionJobs(
  max = 100,
): Promise<WithId<AccountDeletionJobDoc>[]> {
  try {
    const q = query(
      collection(getClientDb(), "accountDeletionJobs"),
      orderBy("requestedAt", "desc"),
      limit(max),
    );
    return mapDocs<AccountDeletionJobDoc>(await getDocs(q));
  } catch {
    return mapDocs<AccountDeletionJobDoc>(
      await getDocs(collection(getClientDb(), "accountDeletionJobs")),
    );
  }
}

/** Cierra un reporte sin sanción (ADM-08). Deja caso + auditoría. */
export async function closeReportWithoutAction(
  reportId: string,
  reason: string,
) {
  const auth = getClientAuth().currentUser;
  if (!auth) throw new Error("No autenticado");
  const db = getClientDb();
  const reportRef = doc(db, "reports", reportId);
  const snap = await getDoc(reportRef);
  if (!snap.exists()) throw new Error("Reporte no encontrado");
  const data = snap.data() as ReportDoc;
  const now = serverTimestamp();

  await updateDoc(reportRef, {
    status: "closedWithoutAction",
    updatedAt: now,
  });

  await addDoc(collection(db, "moderationCases"), {
    reportIds: [reportId],
    targetType: data.targetType === "content" ? "salon" : data.targetType,
    targetId: data.targetId,
    action: "closedWithoutAction",
    reason,
    status: "resolved",
    actorId: auth.uid,
    createdAt: now,
    updatedAt: now,
  });

  await addDoc(collection(db, "auditLogs"), {
    actorId: auth.uid,
    action: "closeReportWithoutAction",
    entityType: "report",
    entityId: reportId,
    reason,
    createdAt: now,
  });
}

export async function getOverviewCounts() {
  const [reports, cases, users, salons, deletionJobs] = await Promise.all([
    listReports({ max: 100 }),
    listModerationCases(100),
    listUsers(200),
    listSalons(200),
    listAccountDeletionJobs(200),
  ]);

  return {
    openReports: reports.filter(
      (r) => r.status === "received" || r.status === "inReview",
    ).length,
    openCases: cases.filter((c) => c.status === "open").length,
    blockedUsers: users.filter(
      (u) => u.moderationStatus === "banned" || u.isBanned,
    ).length,
    deletionRequests: deletionJobs.filter((job) => job.status !== "completed")
      .length,
    suspendedSalons: salons.filter(
      (s) =>
        s.publishStatus === "suspended" ||
        s.publishStatus === "hidden" ||
        s.isDeleted,
    ).length,
  };
}

const APP_CONFIG_SETTINGS_PATH = ["appConfig", "settings"] as const;

const EMPTY_PLATFORM_UPDATE_CONFIG: AppPlatformUpdateConfig = {
  enabled: false,
  requiredVersion: "",
  storeUrl: "",
  releaseNotes: "",
};

function normalizePlatformUpdateConfig(
  value: Partial<AppPlatformUpdateConfig> | undefined,
): AppPlatformUpdateConfig {
  return {
    enabled: value?.enabled === true,
    requiredVersion:
      typeof value?.requiredVersion === "string" ? value.requiredVersion : "",
    storeUrl: typeof value?.storeUrl === "string" ? value.storeUrl : "",
    releaseNotes:
      typeof value?.releaseNotes === "string" ? value.releaseNotes : "",
  };
}

function emptyAppUpdateConfig(): AppUpdateConfig {
  return {
    ios: { ...EMPTY_PLATFORM_UPDATE_CONFIG },
    android: { ...EMPTY_PLATFORM_UPDATE_CONFIG },
  };
}

/** Lee `appConfig/settings`. Si el doc no existe, el flag efectivo es `false`. */
export async function getAppConfigSettings(): Promise<AppConfigSettingsDoc> {
  const snap = await getDoc(doc(getClientDb(), ...APP_CONFIG_SETTINGS_PATH));
  if (!snap.exists()) {
    return { canCreateSalon: false, appUpdate: emptyAppUpdateConfig() };
  }
  const data = snap.data() as Partial<AppConfigSettingsDoc>;
  return {
    canCreateSalon: data.canCreateSalon === true,
    appUpdate: {
      ios: normalizePlatformUpdateConfig(data.appUpdate?.ios),
      android: normalizePlatformUpdateConfig(data.appUpdate?.android),
    },
    updatedAt: data.updatedAt,
  };
}

/** Crea o actualiza `canCreateSalon` en `appConfig/settings` y deja auditoría. */
export async function setCanCreateSalon(enabled: boolean) {
  const auth = getClientAuth().currentUser;
  if (!auth) throw new Error("No autenticado");

  const db = getClientDb();
  const settingsRef = doc(db, ...APP_CONFIG_SETTINGS_PATH);
  const beforeSnap = await getDoc(settingsRef);
  const before = beforeSnap.exists()
    ? (beforeSnap.data() as Partial<AppConfigSettingsDoc>)
    : null;
  const now = serverTimestamp();

  await setDoc(
    settingsRef,
    { canCreateSalon: enabled, updatedAt: now },
    { merge: true },
  );

  await addDoc(collection(db, "auditLogs"), {
    actorId: auth.uid,
    action: "setCanCreateSalon",
    entityType: "appConfig",
    entityId: "settings",
    before: { canCreateSalon: before?.canCreateSalon === true },
    after: { canCreateSalon: enabled },
    createdAt: now,
  });
}

/** Guarda las políticas iOS/Android y registra el cambio administrativo. */
export async function setAppUpdateConfig(appUpdate: AppUpdateConfig) {
  const auth = getClientAuth().currentUser;
  if (!auth) throw new Error("No autenticado");

  const db = getClientDb();
  const settingsRef = doc(db, ...APP_CONFIG_SETTINGS_PATH);
  const beforeSnap = await getDoc(settingsRef);
  const before = beforeSnap.exists()
    ? (beforeSnap.data() as Partial<AppConfigSettingsDoc>)
    : null;
  const now = serverTimestamp();

  await setDoc(settingsRef, { appUpdate, updatedAt: now }, { merge: true });

  await addDoc(collection(db, "auditLogs"), {
    actorId: auth.uid,
    action: "setAppUpdateConfig",
    entityType: "appConfig",
    entityId: "settings",
    before: { appUpdate: before?.appUpdate ?? null },
    after: { appUpdate },
    createdAt: now,
  });
}
