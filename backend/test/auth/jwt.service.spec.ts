import { JwtService } from '../../src';

describe('JwtService', () => {
  const jwt = new JwtService({
    issuer: 'conductor',
    secret: 'test-secret',
    expiresInSeconds: 60,
  });

  it('signs and verifies payloads', () => {
    const token = jwt.sign({ sub: 'user-1', role: 'user' });
    const payload = jwt.verify(token);
    expect(payload.sub).toEqual('user-1');
    expect(payload.role).toEqual('user');
    expect(payload.exp).toBeGreaterThan(Math.floor(Date.now() / 1000));
  });

  it('rejects expired tokens', () => {
    const token = jwt.sign({ sub: 'x', role: 'agent' }, -10);
    expect(() => jwt.verify(token)).toThrow('Token expired');
  });

  it('rejects tampered tokens', () => {
    const token = jwt.sign({ sub: 'x', role: 'agent' });
    const [header, payload] = token.split('.');
    const invalid = `${header}.${payload}.invalid`;
    expect(() => jwt.verify(invalid)).toThrow('Invalid token signature');
  });
});
