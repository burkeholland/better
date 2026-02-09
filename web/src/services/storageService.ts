import { getStorage, ref, uploadBytes, getDownloadURL, deleteObject } from 'firebase/storage';

const storage = getStorage();

const IMAGE_MIME_TYPES = new Set([
  'image/png',
  'image/jpeg',
  'image/webp',
  'image/heic',
  'image/heif',
]);

const PDF_MIME_TYPE = 'application/pdf';
const MAX_IMAGE_BYTES = 15 * 1024 * 1024;
const MAX_PDF_BYTES = 10 * 1024 * 1024;

const validateFile = (file: File): void => {
  if (IMAGE_MIME_TYPES.has(file.type)) {
    if (file.size > MAX_IMAGE_BYTES) {
      throw new Error('Image files must be 15MB or smaller.');
    }
    return;
  }

  if (file.type === PDF_MIME_TYPE) {
    if (file.size > MAX_PDF_BYTES) {
      throw new Error('PDF files must be 10MB or smaller.');
    }
    return;
  }

  throw new Error('Unsupported file type. Use PNG, JPEG, WEBP, HEIC, HEIF, or PDF.');
};

export const getStoragePath = (
  userId: string,
  conversationId: string,
  messageId: string,
  filename: string
): string => `media/${userId}/${conversationId}/${messageId}/${filename}`;

export const uploadFile = async (
  userId: string,
  conversationId: string,
  messageId: string,
  file: File
): Promise<string> => {
  validateFile(file);

  try {
    const path = getStoragePath(userId, conversationId, messageId, file.name);
    const fileRef = ref(storage, path);
    await uploadBytes(fileRef, file, { contentType: file.type });
    return await getDownloadURL(fileRef);
  } catch (error) {
    throw new Error(`Failed to upload file: ${String(error)}`);
  }
};

export const deleteFile = async (url: string): Promise<void> => {
  try {
    const fileRef = ref(storage, url);
    await deleteObject(fileRef);
  } catch (error) {
    throw new Error(`Failed to delete file: ${String(error)}`);
  }
};

export const getFilePreviewURL = (file: File): Promise<string> =>
  new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onloadend = () => resolve(reader.result as string);
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });
