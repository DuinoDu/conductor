import { InMemoryTransport, NotificationService } from '../../src';

describe('NotificationService', () => {
  it('delivers notifications via transport', async () => {
    const transport = new InMemoryTransport();
    const service = new NotificationService(transport);
    const result = await service.notify(
      { userId: 'u1', channel: 'push', address: 'device-token' },
      { title: 'Task Done', body: 'Task completed', taskId: 'task-1' },
    );

    expect(result.success).toBe(true);
    expect(result.attempts).toBe(1);
    expect(transport.deliveries).toHaveLength(1);
  });

  it('retries on failure and records result', async () => {
    const failingTransport = {
      deliveries: [] as Array<{ address: string; payload: string }>,
      async send() {
        throw new Error('network');
      },
    };
    const service = new NotificationService(failingTransport, { maxRetries: 2, backoffMs: 1 });
    const result = await service.notify(
      { userId: 'u2', channel: 'email', address: 'user@example.com' },
      { title: 'Alert', body: 'Something happened' },
    );

    expect(result.success).toBe(false);
    expect(result.attempts).toBe(2);
    expect(result.lastError).toBe('network');
    const stored = service.getDeliveryResult('u2');
    expect(stored?.success).toBe(false);
  });
});
