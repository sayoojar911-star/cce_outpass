import { Injectable, BadRequestException, Logger } from '@nestjs/common';
import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';

export interface ValidatedImage {
  buffer: Buffer;
  extension: 'jpg' | 'png' | 'webp';
  mimeType: 'image/jpeg' | 'image/png' | 'image/webp';
  sizeBytes: number;
}

@Injectable()
export class PhotoStorageService {
  private readonly logger = new Logger(PhotoStorageService.name);
  public static readonly MAX_FILE_SIZE_BYTES = 5 * 1024 * 1024; // 5 MB

  private getUploadDir(): string {
    const uploadDir = path.join(__dirname, '..', '..', 'public', 'uploads', 'students');
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    return uploadDir;
  }

  /**
   * Validates raw image buffer by inspecting true magic bytes (not client MIME/extension).
   * Checks for 5 MB limit and returns canonical extension and MIME.
   */
  validateImageBuffer(buffer: Buffer): ValidatedImage {
    if (!buffer || buffer.length === 0) {
      throw new BadRequestException('Image data cannot be empty');
    }

    if (buffer.length > PhotoStorageService.MAX_FILE_SIZE_BYTES) {
      const sizeMb = (buffer.length / (1024 * 1024)).toFixed(2);
      throw new BadRequestException(
        `Image size (${sizeMb} MB) exceeds maximum allowed limit of 5 MB`,
      );
    }

    // Inspect magic bytes:
    // JPEG: 0xFF 0xD8 0xFF
    if (buffer.length >= 3 && buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) {
      return {
        buffer,
        extension: 'jpg',
        mimeType: 'image/jpeg',
        sizeBytes: buffer.length,
      };
    }

    // PNG: 0x89 0x50 0x4E 0x47 0x0D 0x0A 0x1A 0x0A
    if (
      buffer.length >= 8 &&
      buffer[0] === 0x89 &&
      buffer[1] === 0x50 &&
      buffer[2] === 0x4e &&
      buffer[3] === 0x47 &&
      buffer[4] === 0x0d &&
      buffer[5] === 0x0a &&
      buffer[6] === 0x1a &&
      buffer[7] === 0x0a
    ) {
      return {
        buffer,
        extension: 'png',
        mimeType: 'image/png',
        sizeBytes: buffer.length,
      };
    }

    // WEBP: "RIFF" .... "WEBP"
    if (
      buffer.length >= 12 &&
      buffer[0] === 0x52 &&
      buffer[1] === 0x49 &&
      buffer[2] === 0x46 &&
      buffer[3] === 0x46 &&
      buffer[8] === 0x57 &&
      buffer[9] === 0x45 &&
      buffer[10] === 0x42 &&
      buffer[11] === 0x50
    ) {
      return {
        buffer,
        extension: 'webp',
        mimeType: 'image/webp',
        sizeBytes: buffer.length,
      };
    }

    throw new BadRequestException(
      'Invalid or unsupported image format. Only JPEG, PNG, and WebP images are allowed',
    );
  }

  /**
   * Decodes Data URI or Base64 string to buffer and validates format & size.
   */
  parseAndValidateBase64(base64OrDataUri: string): ValidatedImage {
    if (!base64OrDataUri || typeof base64OrDataUri !== 'string') {
      throw new BadRequestException('Student photo is required');
    }

    let rawBase64 = base64OrDataUri.trim();
    if (rawBase64.startsWith('data:')) {
      const commaIdx = rawBase64.indexOf(',');
      if (commaIdx !== -1) {
        rawBase64 = rawBase64.slice(commaIdx + 1);
      }
    }

    let buffer: Buffer;
    try {
      buffer = Buffer.from(rawBase64, 'base64');
    } catch {
      throw new BadRequestException('Malformed base64 image data');
    }

    if (buffer.length === 0) {
      throw new BadRequestException('Student photo is required');
    }

    return this.validateImageBuffer(buffer);
  }

  /**
   * Saves validated image to persistent storage with unique cryptographic filename.
   * Does NOT trust client-supplied filename or MIME.
   */
  saveImage(validated: ValidatedImage, prefix: string = 'student'): string {
    const uploadDir = this.getUploadDir();
    const uniqueId = crypto.randomBytes(16).toString('hex');
    const fileName = `${prefix}_${uniqueId}_${Date.now()}.${validated.extension}`;
    const filePath = path.join(uploadDir, fileName);

    fs.writeFileSync(filePath, validated.buffer);
    this.logger.log(`Saved persistent photo: ${fileName} (${(validated.sizeBytes / 1024).toFixed(1)} KB)`);

    return `/uploads/students/${fileName}`;
  }

  /**
   * Safely deletes an uploaded photo from disk (e.g. on registration rollback or photo replacement).
   */
  deletePhoto(photoUrl?: string | null): boolean {
    if (!photoUrl || !photoUrl.startsWith('/uploads/students/')) {
      return false;
    }

    try {
      const fileName = path.basename(photoUrl);
      // Ensure fileName does not contain directory traversal
      if (fileName.includes('..') || fileName.includes('/') || fileName.includes('\\')) {
        return false;
      }

      const filePath = path.join(this.getUploadDir(), fileName);
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
        this.logger.log(`Deleted orphaned/previous photo: ${fileName}`);
        return true;
      }
    } catch (err) {
      this.logger.warn(`Failed to delete photo file: ${photoUrl}`, err);
    }
    return false;
  }
}

