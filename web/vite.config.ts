import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  root: '.',
  build: {
    outDir: 'dist',
    emptyOutDir: true,
    chunkSizeWarningLimit: 850,
    rollupOptions: {
      output: {
        manualChunks: {
          react: ['react', 'react-dom'],
          firebase: ['firebase/app', 'firebase/auth', 'firebase/firestore', 'firebase/storage'],
          markdown: ['react-markdown', 'react-syntax-highlighter'],
          ui: ['@headlessui/react', 'framer-motion', 'lucide-react', 'rc-slider', 'clsx'],
          utils: ['tailwind-merge'],
        },
      },
    },
  },
});
