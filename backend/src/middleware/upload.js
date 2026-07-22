import fs from 'fs';
import path from 'path';
import multer from 'multer';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
export const uploadsDir = path.join(__dirname, '../../uploads');

if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

const ALLOWED_EXT = new Set([
  '.jpg',
  '.jpeg',
  '.png',
  '.webp',
  '.gif',
  '.bmp',
  '.tif',
  '.tiff',
  '.heic',
  '.heif',
  '.avif',
  '.pdf',
]);

const ALLOWED_MIME = new Set([
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/webp',
  'image/gif',
  'image/bmp',
  'image/tiff',
  'image/heic',
  'image/heif',
  'image/avif',
  'image/x-png',
  'application/pdf',
  'application/x-pdf',
]);

function isAllowedFile(file) {
  const mime = String(file.mimetype || '').toLowerCase();
  const ext = path.extname(file.originalname || '').toLowerCase();
  if (mime.startsWith('image/')) return true;
  if (ALLOWED_MIME.has(mime)) return true;
  if (ALLOWED_EXT.has(ext)) return true;
  return false;
}

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadsDir),
  filename: (_req, file, cb) => {
    const safe = String(file.originalname || 'file')
      .replace(/[^a-zA-Z0-9._-]/g, '_')
      .slice(-80);
    cb(null, `${Date.now()}_${Math.random().toString(36).slice(2, 8)}_${safe}`);
  },
});

export const upload = multer({
  storage,
  limits: { fileSize: 12 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    if (isAllowedFile(file)) return cb(null, true);
    cb(
      new Error(
        'Unsupported file. Use an image (JPG, PNG, WEBP, HEIC, GIF, BMP, TIFF, AVIF) or PDF',
      ),
    );
  },
});

export function publicUploadUrl(filename, req = null) {
  const path = `/uploads/${filename}`;
  if (req) {
    const host = req.get?.('host') || req.headers?.host;
    if (host) {
      const proto = req.protocol || 'http';
      return `${proto}://${host}${path}`;
    }
  }
  const base = (process.env.PUBLIC_API_URL || 'http://localhost:4000').replace(
    /\/$/,
    '',
  );
  return `${base}${path}`;
}
