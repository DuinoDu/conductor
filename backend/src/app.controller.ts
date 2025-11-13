import { Body, Controller, Delete, Get, Post } from '@nestjs/common';

@Controller()
export class AppController {
  private static events: any[] = [];

  @Get('health')
  health() {
    return { status: 'ok', timestamp: new Date().toISOString() };
  }

  @Post('events')
  async recordEvent(@Body() body: any) {
    AppController.events.push(body);
    return { ok: true, count: AppController.events.length };
  }

  @Get('events')
  listEvents() {
    return AppController.events;
  }

  @Delete('events')
  clearEvents() {
    AppController.events = [];
    return { ok: true };
  }
}
