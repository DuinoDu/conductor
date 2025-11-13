export type ConnectionKind = 'app' | 'agent';

export interface RealtimeConnection {
  id: string;
  kind: ConnectionKind;
  projectIds: string[];
  send: (payload: unknown) => void;
}

export interface RoutePayload {
  taskId: string;
  projectId: string;
  type: string;
  data: unknown;
}
