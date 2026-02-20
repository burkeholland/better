import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

admin.initializeApp();

const openRouterApiKey = defineSecret("OPENROUTER_API_KEY");
const tavilyApiKey = defineSecret("TAVILY_API_KEY");

const OPENROUTER_BASE = "https://openrouter.ai/api/v1/";

// Allowed OpenRouter endpoints that clients can proxy through
const ALLOWED_PATHS = ["chat/completions", "jobs/", "search"];

/**
 * SSE proxy for OpenRouter API.
 * Verifies Firebase Auth, forwards request, streams response back.
 */
export const api = onRequest(
  {
    region: "us-central1",
    memory: "256MiB",
    timeoutSeconds: 300, // 5 min for long streaming responses / video jobs
    secrets: [openRouterApiKey, tavilyApiKey],
  },
  async (req, res) => {
    // CORS preflight
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Headers", "Authorization, Content-Type, X-OpenRouter-Path");
    res.set("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    // --- Auth ---
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith("Bearer ")) {
      res.status(401).json({ error: "Missing or invalid Authorization header" });
      return;
    }

    const idToken = authHeader.split("Bearer ")[1];
    let uid: string;
    try {
      const decoded = await admin.auth().verifyIdToken(idToken);
      uid = decoded.uid;
    } catch (err) {
      logger.warn("Auth failed", { error: err });
      res.status(401).json({ error: "Invalid Firebase ID token" });
      return;
    }

    // --- Route ---
    // Client sends the OpenRouter sub-path in X-OpenRouter-Path header
    const subPath = req.headers["x-openrouter-path"] as string || "chat/completions";
    if (!ALLOWED_PATHS.some((p) => subPath.startsWith(p))) {
      res.status(400).json({ error: `Path not allowed: ${subPath}` });
      return;
    }

    const targetUrl = `${OPENROUTER_BASE}${subPath}`;
    const apiKey = openRouterApiKey.value();

    logger.info("Proxying request", { uid, path: subPath, method: req.method });

    // --- Search (Tavily) ---
    if (subPath === "search") {
      try {
        const searchKey = tavilyApiKey.value();
        if (!searchKey) {
          res.status(503).json({ error: "Search service not configured" });
          return;
        }

        const searchBody = {
          api_key: searchKey,
          query: req.body?.query || "",
          max_results: req.body?.max_results || 5,
          search_depth: "basic",
        };

        const searchResponse = await fetch("https://api.tavily.com/search", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(searchBody),
        });

        const searchData = await searchResponse.json();
        res.status(searchResponse.status).json(searchData);
      } catch (err) {
        logger.error("Search error", { error: err, uid });
        res.status(502).json({ error: "Search request failed" });
      }
      return;
    }

    // --- Proxy (OpenRouter) ---
    try {
      const headers: Record<string, string> = {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
        "HTTP-Referer": "https://better.postrboard.com",
        "X-Title": "Better",
      };

      // For streaming requests, also set Accept header
      const body = req.body;
      const isStreaming = body?.stream === true;
      if (isStreaming) {
        headers["Accept"] = "text/event-stream";
      }

      const fetchOptions: RequestInit = {
        method: req.method,
        headers,
      };

      // Include body for POST requests
      if (req.method === "POST" && body) {
        fetchOptions.body = JSON.stringify(body);
      }

      const upstream = await fetch(targetUrl, fetchOptions);

      // Pass through status code
      res.status(upstream.status);

      if (isStreaming && upstream.ok && upstream.body) {
        // Stream SSE response
        res.set("Content-Type", "text/event-stream");
        res.set("Cache-Control", "no-cache");
        res.set("Connection", "keep-alive");
        res.set("Transfer-Encoding", "chunked");

        const reader = upstream.body.getReader();
        try {
          while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            res.write(value);
          }
        } catch (streamErr) {
          logger.error("Stream error", { error: streamErr, uid });
        }
        res.end();
      } else {
        // Non-streaming: pass through response
        const contentType = upstream.headers.get("content-type") || "application/json";
        res.set("Content-Type", contentType);
        const responseData = await upstream.arrayBuffer();
        res.send(Buffer.from(responseData));
      }
    } catch (err) {
      logger.error("Proxy error", { error: err, uid, path: subPath });
      res.status(502).json({ error: "Failed to reach upstream API" });
    }
  }
);
