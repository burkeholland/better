import { spawnSync } from 'node:child_process';
import { writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const webRoot = resolve(__dirname, '..');
const envPath = resolve(webRoot, '.env.local');

const runFirebase = (args) => {
  const result = spawnSync('firebase', args, { encoding: 'utf8' });

  if (result.error && result.error.code === 'ENOENT') {
    throw new Error('Firebase CLI not found. Install it with `npm install -g firebase-tools`.');
  }

  if (result.status !== 0) {
    const details = result.stderr?.trim() || result.stdout?.trim();
    throw new Error(details || 'Firebase CLI command failed.');
  }

  return result.stdout;
};

const parseJson = (value, label) => {
  try {
    return JSON.parse(value);
  } catch (error) {
    throw new Error(`Unable to parse ${label} JSON output.`);
  }
};

const resolveWebAppId = (listData) => {
  const apps = listData?.result?.apps ?? listData?.apps ?? [];
  const webApp = apps.find((app) => app.platform === 'WEB');
  return webApp?.appId ?? null;
};

const resolveSdkConfig = (sdkData) => {
  return sdkData?.result?.sdkConfig ?? sdkData?.sdkConfig ?? sdkData?.result ?? sdkData;
};

const buildEnvContent = (config) => {
  const entries = {
    VITE_FIREBASE_API_KEY: config.apiKey,
    VITE_FIREBASE_AUTH_DOMAIN: config.authDomain,
    VITE_FIREBASE_PROJECT_ID: config.projectId,
    VITE_FIREBASE_STORAGE_BUCKET: config.storageBucket,
    VITE_FIREBASE_MESSAGING_SENDER_ID: config.messagingSenderId,
    VITE_FIREBASE_APP_ID: config.appId
  };

  const missing = Object.entries(entries)
    .filter(([, value]) => !value)
    .map(([key]) => key);

  if (missing.length > 0) {
    throw new Error(`Missing Firebase config values: ${missing.join(', ')}`);
  }

  return Object.entries(entries)
    .map(([key, value]) => `${key}=${value}`)
    .join('\n')
    .concat('\n');
};

const main = async () => {
  const listOutput = runFirebase(['apps:list', '--json']);
  const listData = parseJson(listOutput, 'apps list');

  let appId = resolveWebAppId(listData);

  if (!appId) {
    const createOutput = runFirebase([
      'apps:create',
      'WEB',
      '--display-name',
      'Better Web',
      '--json'
    ]);
    const createData = parseJson(createOutput, 'apps create');
    appId = createData?.result?.appId ?? createData?.appId ?? null;
  }

  if (!appId) {
    throw new Error('Unable to determine Firebase web app ID.');
  }

  const sdkOutput = runFirebase(['apps:sdkconfig', 'web', appId, '--json']);
  const sdkData = parseJson(sdkOutput, 'sdkconfig');
  const sdkConfig = resolveSdkConfig(sdkData);
  const envContent = buildEnvContent(sdkConfig);

  await writeFile(envPath, envContent, 'utf8');

  console.log(`Wrote Firebase config to ${envPath}`);
};

main().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
