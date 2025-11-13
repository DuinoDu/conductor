import { NotificationPayload, NotifyTarget, DeliveryResult } from './types';
import { NotificationTransport } from './transport';

export interface NotificationServiceOptions {
  maxRetries?: number;
  backoffMs?: number;
}

export class NotificationService {
  private readonly maxRetries: number;
  private readonly backoffMs: number;
  private readonly sentRecords = new Map<string, DeliveryResult>();

  constructor(
    private readonly transport: NotificationTransport,
    options: NotificationServiceOptions = {},
  ) {
    this.maxRetries = options.maxRetries ?? 3;
    this.backoffMs = options.backoffMs ?? 100;
  }

  async notify(target: NotifyTarget, payload: NotificationPayload): Promise<DeliveryResult> {
    const cacheKey = `${target.userId}:${payload.taskId ?? 'general'}`;
    let attempts = 0;
    let lastError: string | undefined;

    while (attempts < this.maxRetries) {
      attempts += 1;
      try {
        const serialized = JSON.stringify({
          channel: target.channel,
          address: target.address,
          payload,
        });
        await this.transport.send(target.address, serialized);
        const result: DeliveryResult = { success: true, attempts };
        this.sentRecords.set(cacheKey, result);
        return result;
      } catch (error) {
        lastError = error instanceof Error ? error.message : String(error);
        if (attempts < this.maxRetries) {
          await this.delay(this.backoffMs * attempts);
        }
      }
    }

    const failure: DeliveryResult = { success: false, attempts, lastError };
    this.sentRecords.set(cacheKey, failure);
    return failure;
  }

  getDeliveryResult(userId: string, taskId?: string): DeliveryResult | undefined {
    return this.sentRecords.get(`${userId}:${taskId ?? 'general'}`);
  }

  private delay(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}
