import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ServeStaticModule } from '@nestjs/serve-static';
import { join } from 'path';
import { ScheduleModule } from '@nestjs/schedule';
import { PrismaService } from './prisma.service';
import { AuthModule } from './auth/auth.module';
import { OutpassModule } from './outpass/outpass.module';
import { GateModule } from './gate/gate.module';
import { NotificationsModule } from './notifications/notifications.module';
import { ExpiryService } from './jobs/expiry.service';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    ScheduleModule.forRoot(),
    // Serves the built Flutter web app at / (single process for the demo).
    ServeStaticModule.forRoot({
      rootPath: join(__dirname, '..', '..', 'public'),
      exclude: ['/v1*', '/v1/**'],
      serveStaticOptions: {
        setHeaders: (res: any, path: string) => {
          if (
            path.endsWith('.html') ||
            path.endsWith('.js') ||
            path.endsWith('.css') ||
            path.endsWith('.json')
          ) {
            res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');
            res.setHeader('Pragma', 'no-cache');
            res.setHeader('Expires', '0');
          }
        },
      },
    }),
    AuthModule,
    OutpassModule,
    GateModule,
    NotificationsModule,
  ],
  providers: [PrismaService, ExpiryService],
})
export class AppModule {}
