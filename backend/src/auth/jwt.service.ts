import * as crypto from 'crypto';

export interface JwtPayload {
  sub: string;
  role: 'user' | 'agent';
  exp: number;
  scopes?: string[];
}

export interface JwtConfig {
  issuer: string;
  expiresInSeconds: number;
  secret: string;
}

export class JwtService {
  constructor(private readonly config: JwtConfig) {}

  sign(payload: Omit<JwtPayload, 'exp'>, expiresInSeconds?: number): string {
    const header = { alg: 'HS256', typ: 'JWT' };
    const exp = Math.floor(Date.now() / 1000) + (expiresInSeconds ?? this.config.expiresInSeconds);
    const fullPayload: JwtPayload = { ...payload, exp };

    const segments = [
      this.base64UrlEncode(JSON.stringify(header)),
      this.base64UrlEncode(JSON.stringify({ ...fullPayload, iss: this.config.issuer })),
    ];
    const signature = this.signSegments(segments);
    return [...segments, signature].join('.');
  }

  verify(token: string): JwtPayload {
    const [headerB64, payloadB64, signature] = token.split('.');
    if (!headerB64 || !payloadB64 || !signature) {
      throw new Error('Invalid token format');
    }

    const expectedSignature = this.signSegments([headerB64, payloadB64]);
    const provided = Buffer.from(signature);
    const expected = Buffer.from(expectedSignature);
    if (provided.length !== expected.length) {
      throw new Error('Invalid token signature');
    }
    if (!crypto.timingSafeEqual(provided, expected)) {
      throw new Error('Invalid token signature');
    }

    const payload: JwtPayload = JSON.parse(this.base64UrlDecode(payloadB64));
    if (payload.exp * 1000 < Date.now()) {
      throw new Error('Token expired');
    }

    return payload;
  }

  private signSegments(segments: string[]): string {
    const hmac = crypto.createHmac('sha256', this.config.secret);
    hmac.update(segments.join('.'));
    return this.base64UrlEncode(hmac.digest());
  }

  private base64UrlEncode(value: string | Buffer): string {
    return Buffer.from(value)
      .toString('base64')
      .replace(/=/g, '')
      .replace(/\+/g, '-')
      .replace(/\//g, '_');
  }

  private base64UrlDecode(value: string): string {
    const pad = value.length % 4;
    const normalized = value + (pad ? '='.repeat(4 - pad) : '');
    return Buffer.from(normalized.replace(/-/g, '+').replace(/_/g, '/'), 'base64').toString();
  }
}
