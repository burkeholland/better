import { useEffect, useRef, useState } from 'react';
import { Camera, FileText, Loader2, Send, Square, X } from 'lucide-react';
import { getFilePreviewURL } from '../../services/storageService';

const LATEST_FLASH = 'gemini-flash-latest';
const LATEST_PRO = 'gemini-pro-latest';

interface MessageInputProps {
  onSend: (text: string, attachment: File | null) => void;
  isGenerating: boolean;
  isUploading: boolean;
  onStop: () => void;
  modelName: string;
  onModelToggle: (model: string) => void;
}

const IMAGE_MIME_TYPES = ['image/png', 'image/jpeg', 'image/webp', 'image/heic', 'image/heif'];
const MAX_IMAGE_BYTES = 15 * 1024 * 1024;
const MAX_PDF_BYTES = 10 * 1024 * 1024;

const validateImage = (file: File): boolean =>
  IMAGE_MIME_TYPES.includes(file.type) && file.size <= MAX_IMAGE_BYTES;

const validatePDF = (file: File): boolean =>
  file.type === 'application/pdf' && file.size <= MAX_PDF_BYTES;

const isProModel = (name: string): boolean => /pro/i.test(name);

const MessageInput = ({
  onSend,
  isGenerating,
  isUploading,
  onStop,
  modelName,
  onModelToggle,
}: MessageInputProps) => {
  const [text, setText] = useState('');
  const [selectedImage, setSelectedImage] = useState<File | null>(null);
  const [selectedPDF, setSelectedPDF] = useState<File | null>(null);
  const [imagePreviewURL, setImagePreviewURL] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const imageInputRef = useRef<HTMLInputElement>(null);
  const pdfInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (textareaRef.current) {
      textareaRef.current.style.height = 'auto';
      textareaRef.current.style.height = `${Math.min(textareaRef.current.scrollHeight, 160)}px`;
    }
  }, [text]);

  const resetAttachments = () => {
    setSelectedImage(null);
    setSelectedPDF(null);
    setImagePreviewURL(null);
  };

  const handleSend = () => {
    const attachment = selectedImage ?? selectedPDF;
    if ((!text.trim() && !attachment) || isGenerating || isUploading) return;
    onSend(text, attachment ?? null);
    setText('');
    resetAttachments();
    setErrorMessage(null);
    if (textareaRef.current) textareaRef.current.style.height = 'auto';
  };

  const handleKeyDown = (event: React.KeyboardEvent) => {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault();
      handleSend();
    }
  };

  const handleImageSelect = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;

    if (!validateImage(file)) {
      setErrorMessage('Unsupported image type or file exceeds 15MB.');
      if (imageInputRef.current) imageInputRef.current.value = '';
      return;
    }

    setErrorMessage(null);
    setSelectedImage(file);
    setSelectedPDF(null);

    try {
      const previewURL = await getFilePreviewURL(file);
      setImagePreviewURL(previewURL);
    } catch (error) {
      setErrorMessage('Unable to load image preview.');
      setSelectedImage(null);
      setImagePreviewURL(null);
    }

    if (imageInputRef.current) imageInputRef.current.value = '';
  };

  const handlePdfSelect = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;

    if (!validatePDF(file)) {
      setErrorMessage('Unsupported PDF or file exceeds 10MB.');
      if (pdfInputRef.current) pdfInputRef.current.value = '';
      return;
    }

    setErrorMessage(null);
    setSelectedPDF(file);
    setSelectedImage(null);
    setImagePreviewURL(null);

    if (pdfInputRef.current) pdfInputRef.current.value = '';
  };

  const removeAttachment = () => {
    resetAttachments();
  };

  const triggerFilePicker = (type: 'image' | 'pdf') => {
    if (type === 'image' && imageInputRef.current) {
      imageInputRef.current.click();
    }
    if (type === 'pdf' && pdfInputRef.current) {
      pdfInputRef.current.click();
    }
  };

  return (
    <div className="w-full max-w-4xl mx-auto px-4 pb-4">
      <div className="relative glass-panel rounded-[24px] shadow-input transition-shadow duration-200 hover:shadow-lg bg-white/50 dark:bg-charcoal/50 backdrop-blur-xl border border-white/20 dark:border-white/10">
        {(selectedImage || selectedPDF) && (
          <div className="flex gap-2 p-3 overflow-x-auto no-scrollbar border-b border-black/5 dark:border-white/5">
            <div className="relative flex-shrink-0 group">
              <div className="w-16 h-16 rounded-lg overflow-hidden border border-black/10 dark:border-white/10 bg-white dark:bg-black/20 flex items-center justify-center">
                {selectedImage && imagePreviewURL ? (
                  <img src={imagePreviewURL} alt="preview" className="w-full h-full object-cover" />
                ) : (
                  <FileText size={24} className="text-peach" />
                )}
              </div>
              <button
                onClick={removeAttachment}
                className="absolute -top-1 -right-1 bg-black/50 text-white rounded-full p-0.5 opacity-0 group-hover:opacity-100 transition-opacity"
                aria-label="Remove attachment"
                type="button"
              >
                <X size={12} />
              </button>
            </div>
            {selectedPDF && (
              <div className="flex items-center gap-2 px-3 py-2 rounded-lg border border-black/10 dark:border-white/10 bg-white/70 dark:bg-black/20 text-xs text-darkGray dark:text-lightGray">
                <FileText size={16} className="text-peach" />
                <span className="max-w-[160px] truncate">{selectedPDF.name}</span>
              </div>
            )}
          </div>
        )}

        <div className="flex items-end gap-2 p-2">
          <div className="hidden sm:flex self-center ml-2 mr-2">
            <button
              onClick={() => onModelToggle(isProModel(modelName) ? LATEST_FLASH : LATEST_PRO)}
              className="px-3 py-1.5 rounded-full bg-black/5 dark:bg-white/10 hover:bg-black/10 dark:hover:bg-white/20 transition-colors text-xs font-semibold text-charcoal dark:text-lightGray"
              type="button"
            >
              {isProModel(modelName) ? 'Pro' : 'Flash'}
            </button>
          </div>

          <button
            onClick={() => triggerFilePicker('image')}
            className="p-3 text-darkGray/60 dark:text-lightGray/60 hover:text-peach transition-colors rounded-full hover:bg-black/5 dark:hover:bg-white/5"
            title="Add Image"
            type="button"
          >
            <Camera size={22} />
          </button>

          <button
            onClick={() => triggerFilePicker('pdf')}
            className="p-3 text-darkGray/60 dark:text-lightGray/60 hover:text-peach transition-colors rounded-full hover:bg-black/5 dark:hover:bg-white/5"
            title="Add PDF"
            type="button"
          >
            <FileText size={22} />
          </button>

          <input
            type="file"
            ref={imageInputRef}
            className="hidden"
            accept="image/png,image/jpeg,image/webp,image/heic,image/heif"
            onChange={handleImageSelect}
          />

          <input
            type="file"
            ref={pdfInputRef}
            className="hidden"
            accept="application/pdf"
            onChange={handlePdfSelect}
          />

          <textarea
            ref={textareaRef}
            value={text}
            onChange={(event) => setText(event.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="Message Better..."
            rows={1}
            className="flex-1 max-h-40 py-3 bg-transparent border-none outline-none resize-none text-charcoal dark:text-cream placeholder-darkGray/40 dark:placeholder-lightGray/30 leading-relaxed"
            style={{ minHeight: '44px' }}
          />

          <div className="p-1">
            <button
              onClick={isGenerating ? onStop : handleSend}
              disabled={isUploading || (!isGenerating && !text.trim() && !selectedImage && !selectedPDF)}
              className={
                `
                        w-10 h-10 flex items-center justify-center rounded-full transition-all duration-300 shadow-sm
                        ${isGenerating 
                            ? 'bg-red-500 hover:bg-red-600 text-white' 
                            : 'text-white disabled:opacity-50 disabled:cursor-not-allowed transform hover:scale-105 active:scale-95'
                        }
                    `
              }
              style={{
                background: isGenerating ? undefined : 'var(--gradient-send-button)',
              }}
              type="button"
            >
              {isGenerating ? (
                <Square size={16} fill="white" />
              ) : isUploading ? (
                <Loader2 size={18} className="animate-spin" />
              ) : (
                <Send size={18} className="translate-x-0.5 translate-y-0.5" />
              )}
            </button>
          </div>
        </div>
      </div>

      {errorMessage && (
        <div className="mt-2 text-center text-xs text-red-500">{errorMessage}</div>
      )}

      <div className="mt-2 text-center">
        <p className="text-[10px] text-darkGray/40 dark:text-lightGray/30">
          Gemini can make mistakes. Consider checking important information.
        </p>
      </div>
    </div>
  );
};

export default MessageInput;
