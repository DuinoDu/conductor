export type NotificationChannel = 'push' | 'email';

export interface NotificationPayload {
  title: string;
  body: string;
  taskId?: string;
  severity?: 'info' | 'warning' | 'error';
  metadata?: Record<string, unknown>;
}

export interface NotifyTarget {
  userId: string;
  channel: NotificationChannel;
  address: string;
}

export interface DeliveryResult {
  success: boolean;
  attempts: number;
  lastError?: string;
}
