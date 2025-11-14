import { Global, Module } from '@nestjs/common';

import { RealtimeHub } from './realtime.hub';

@Global()
@Module({
  providers: [
    {
      provide: RealtimeHub,
      useFactory: () => new RealtimeHub(),
    },
  ],
  exports: [RealtimeHub],
})
export class RealtimeModule {}
