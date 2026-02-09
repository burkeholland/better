import { getStorage, ref, getDownloadURL } from 'firebase/storage';

const MAX_DOWNLOAD_BYTES = 15 * 1024 * 1024;

type CachedMedia = {
  data: string;
  mimeType: string;
};

const cache = new Map<string, CachedMedia>();
const urlCache = new Map<string, string>(); // Cache for resolved Storage URLs

// Check if URL looks like a relative Firebase Storage path
export const isRelativeStoragePath = (url: string): boolean => {
  if (!url) return false;
  // Relative paths starting with 'media/' are Storage references
  return url.startsWith('media/') && !url.startsWith('http');
};

// Check if URL is web-accessible (not file:// or other local schemes)
export const isWebAccessibleURL = (url: string): boolean => {
  if (!url) return false;
  // Allow data URLs (already base64)
  if (url.startsWith('data:')) return true;
  // Allow http/https URLs
  if (url.startsWith('http://') || url.startsWith('https://')) return true;
  // Relative Storage paths can be resolved
  if (isRelativeStoragePath(url)) return true;
  // Reject file:// URLs and other schemes
  return false;
};

// Resolve a relative Storage path to a full download URL
export const resolveStorageURL = async (url: string): Promise<string> => {
  // Already a full URL
  if (url.startsWith('http://') || url.startsWith('https://') || url.startsWith('data:')) {
    return url;
  }

  // Check cache
  const cached = urlCache.get(url);
  if (cached) {
    return cached;
  }

  // Not a relative Storage path, can't resolve
  if (!isRelativeStoragePath(url)) {
    throw new Error('Cannot resolve URL: not a valid Storage path');
  }

  // Resolve the Storage reference to a download URL
  try {
    const storage = getStorage();
    const storageRef = ref(storage, url);
    const downloadURL = await getDownloadURL(storageRef);
    urlCache.set(url, downloadURL);
    return downloadURL;
  } catch (error) {
    throw new Error(`Failed to resolve Storage URL: ${error}`);
  }
};

const arrayBufferToBase64 = (buffer: ArrayBuffer): string => {
  const bytes = new Uint8Array(buffer);
  const chunkSize = 0x8000;
  let binary = '';

  for (let i = 0; i < bytes.length; i += chunkSize) {
    const chunk = bytes.subarray(i, i + chunkSize);
    binary += String.fromCharCode(...chunk);
  }

  return btoa(binary);
};

export const downloadMediaAsBase64 = async (
  url: string,
  mimeType: string
): Promise<{ data: string; mimeType: string }> => {
  // Reject non-web URLs (like file:// from iOS simulator)
  if (!isWebAccessibleURL(url)) {
    throw new Error('Media URL is not web-accessible (local file path).');
  }

  // Handle data URLs (already base64 encoded)
  if (url.startsWith('data:')) {
    const commaIndex = url.indexOf(',');
    if (commaIndex === -1) {
      throw new Error('Invalid data URL format.');
    }
    const data = url.substring(commaIndex + 1);
    return { data, mimeType };
  }

  // Resolve relative Storage paths to full URLs
  let resolvedURL = url;
  if (isRelativeStoragePath(url)) {
    resolvedURL = await resolveStorageURL(url);
  }

  const cached = cache.get(resolvedURL);
  if (cached) {
    return cached;
  }

  const response = await fetch(resolvedURL);
  if (!response.ok) {
    throw new Error(`Failed to download media: ${response.status} ${response.statusText}`);
  }

  const contentLength = response.headers.get('content-length');
  if (contentLength && Number(contentLength) > MAX_DOWNLOAD_BYTES) {
    throw new Error('Media download exceeds the 15MB limit.');
  }

  const arrayBuffer = await response.arrayBuffer();
  if (arrayBuffer.byteLength > MAX_DOWNLOAD_BYTES) {
    throw new Error('Media download exceeds the 15MB limit.');
  }

  const data = arrayBufferToBase64(arrayBuffer);
  const result = { data, mimeType };
  cache.set(url, result);

  return result;
};

export const clearCache = (): void => {
  cache.clear();
};
