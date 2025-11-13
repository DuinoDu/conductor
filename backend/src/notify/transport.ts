export interface NotificationTransport {
  send(address: string, payload: string): Promise<void>;
}

export class InMemoryTransport implements NotificationTransport {
  public readonly deliveries: Array<{ address: string; payload: string }> = [];

  async send(address: string, payload: string): Promise<void> {
    this.deliveries.push({ address, payload });
  }
}
