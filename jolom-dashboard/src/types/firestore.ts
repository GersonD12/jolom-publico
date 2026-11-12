import type { Timestamp } from "firebase/firestore";

export type ModerationStatus = "none" | "warned" | "banned";

export type ReportStatus =
  | "received"
  | "inReview"
  | "closedWithAction"
  | "closedWithoutAction";

export type ReportTargetType = "user" | "barber" | "salon" | "content";

export type PublishStatus =
  | "draft"
  | "published"
  | "hidden"
  | "suspended"
  | "deleted";

export type ModerationActionType =
  | "warn"
  | "suspend"
  | "ban"
  | "unban"
  | "unpublish"
  | "softDelete"
  | "restore";

export type UserDoc = {
  email: string | null;
  displayName: string | null;
  photoUrl: string | null;
  phone: string | null;
  capabilities: { client: boolean; barber: boolean };
  deletionRequestedAt?: Timestamp | null;
  deletionStartedAt?: Timestamp | null;
  deletionCompletedAt?: Timestamp | null;
  accountStatus?: "active" | "deletionPending" | "deleting" | "deleted";
  isBanned: boolean;
  isDeleted: boolean;
  moderationStatus: ModerationStatus;
  moderationReason?: string | null;
  locale?: string;
  createdAt?: Timestamp;
  updatedAt?: Timestamp;
};

export type AccountDeletionJobDoc = {
  userId?: string;
  anonymousId: string;
  actorType: "self" | "admin" | "migration";
  role: "client" | "barber" | "owner";
  status: "queued" | "processing" | "failed" | "completed";
  attempts: number;
  salonIds?: string[];
  counters?: Record<string, number>;
  lastError?: string | null;
  requestedAt?: Timestamp | null;
  startedAt?: Timestamp | null;
  completedAt?: Timestamp | null;
  updatedAt?: Timestamp | null;
};

export type BarberProfileDoc = {
  userId: string;
  bio?: string;
  status: "draft" | "active" | "suspended";
  createdAt?: Timestamp;
  updatedAt?: Timestamp;
};

export type SalonDoc = {
  ownerId: string;
  name: string;
  description?: string;
  contactPhone?: string;
  contactEmail?: string;
  address?: string;
  city: string;
  coverImageUrl?: string;
  currency: string;
  timeZone: string;
  publishStatus: PublishStatus;
  isDeleted: boolean;
  createdAt?: Timestamp;
  updatedAt?: Timestamp;
};

export type SalonMembershipDoc = {
  userId: string;
  salonId: string;
  role: "owner" | "barber";
  status: "active" | "pendingExit" | "withdrawn";
  invitationId?: string;
  joinedAt?: Timestamp;
  leftAt?: Timestamp;
  updatedAt?: Timestamp;
};

export type ReportDoc = {
  reporterId: string;
  targetType: ReportTargetType;
  targetId: string;
  category: string;
  description: string;
  sourceAppointmentId?: string;
  sourceSalonId?: string;
  status: ReportStatus;
  dedupeKey?: string;
  createdAt?: Timestamp;
  updatedAt?: Timestamp;
};

export type ModerationCaseDoc = {
  reportIds: string[];
  targetType: "user" | "barber" | "salon";
  targetId: string;
  action: string;
  reason: string;
  scope?: string | null;
  status: "open" | "resolved";
  actorId: string;
  severity?: "low" | "medium" | "high";
  notesInternal?: string;
  resolution?: string;
  createdAt?: Timestamp;
  updatedAt?: Timestamp;
};

export type AuditLogDoc = {
  actorId: string;
  action: string;
  entityType: string;
  entityId: string;
  before?: unknown;
  after?: unknown;
  reason?: string;
  createdAt?: Timestamp;
};

export type ServiceDoc = {
  salonId: string;
  name: string;
  description?: string;
  durationMinutes: number;
  price: number;
  currency: string;
  enabledBarberIds: string[];
  status: "active" | "inactive";
  isDeleted: boolean;
};

export type AppPlatformUpdateConfig = {
  enabled: boolean;
  requiredVersion: string;
  storeUrl: string;
  releaseNotes: string;
};

export type AppUpdateConfig = {
  ios: AppPlatformUpdateConfig;
  android: AppPlatformUpdateConfig;
};

export type AppConfigSettingsDoc = {
  canCreateSalon: boolean;
  appUpdate: AppUpdateConfig;
  updatedAt?: Timestamp;
};
