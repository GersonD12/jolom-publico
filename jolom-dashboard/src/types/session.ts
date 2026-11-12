/**
 * Session contracts for the admin dashboard.
 * Access is gated by Firebase Auth custom claim `role: "admin"`.
 */
export type Role = "admin";

export type SessionUser = {
  id: string;
  email: string;
  name?: string;
  photoUrl?: string;
  role: Role;
};
