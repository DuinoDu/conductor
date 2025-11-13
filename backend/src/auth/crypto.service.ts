import * as crypto from 'crypto';

export class CryptoService {
  private readonly iterations = 100_000;
  private readonly keyLength = 32;
  private readonly digest = 'sha256';

  hashSecret(secret: string, salt?: string): { hash: string; salt: string } {
    const finalSalt = salt ?? crypto.randomBytes(16).toString('hex');
    const derived = crypto
      .pbkdf2Sync(secret, finalSalt, this.iterations, this.keyLength, this.digest)
      .toString('hex');
    return { hash: derived, salt: finalSalt };
  }

  verifySecret(secret: string, hash: string, salt: string): boolean {
    const result = this.hashSecret(secret, salt);
    return crypto.timingSafeEqual(Buffer.from(hash), Buffer.from(result.hash));
  }
}
