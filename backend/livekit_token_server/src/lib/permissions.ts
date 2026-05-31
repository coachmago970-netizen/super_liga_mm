export type ServerRole = "owner" | "admin" | "moderator" | "member";

const roleRank: Record<ServerRole, number> = {
  owner: 4,
  admin: 3,
  moderator: 2,
  member: 1
};

export function canManageInvites(role: ServerRole): boolean {
  return role === "owner" || role === "admin";
}

export function canManageChannels(role: ServerRole): boolean {
  return role === "owner" || role === "admin" || role === "moderator";
}

export function canViewMembers(role: ServerRole): boolean {
  return role === "owner" || role === "admin" || role === "moderator";
}

export function canViewLogs(role: ServerRole): boolean {
  return role === "owner" || role === "admin" || role === "moderator";
}

export function canKickMembers(role: ServerRole): boolean {
  return role === "owner" || role === "admin" || role === "moderator";
}

export function canMuteMembers(role: ServerRole): boolean {
  return role === "owner" || role === "admin" || role === "moderator";
}

export function canBanMembers(role: ServerRole): boolean {
  return role === "owner" || role === "admin";
}

export function canChangeRoles(role: ServerRole): boolean {
  return role === "owner" || role === "admin";
}

export function canTargetRole(actorRole: ServerRole, targetRole: ServerRole): boolean {
  return roleRank[actorRole] > roleRank[targetRole];
}

export function canAssignRole(actorRole: ServerRole, desiredRole: ServerRole): boolean {
  if (actorRole === "owner") return true;
  if (actorRole === "admin") return desiredRole === "moderator" || desiredRole === "member";
  return false;
}
