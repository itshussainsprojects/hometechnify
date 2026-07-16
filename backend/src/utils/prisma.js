
const { PrismaClient } = require('@prisma/client');

const isTransient = (e) => {
    if (!e) return false;
    // Known transient Prisma error codes
    if (e.code === 'P1001' || e.code === 'P1017' || e.code === 'P2024') return true;
    // Client can't establish the initial connection (pooler blip / cold start)
    if (e.name === 'PrismaClientInitializationError') return true;
    // Fallback: match the connection-drop message
    if (typeof e.message === 'string' && /can't reach database server|connection.*closed|ECONNRESET|ETIMEDOUT|Timed out/i.test(e.message)) return true;
    return false;
};

async function _retry(fn, retries = 4, delayMs = 400) {
    let lastErr;
    for (let i = 0; i <= retries; i++) {
        try {
            return await fn();
        } catch (e) {
            lastErr = e;
            if (!isTransient(e) || i === retries) throw e;
            await new Promise(r => setTimeout(r, delayMs * (i + 1)));
        }
    }
    throw lastErr;
}

// Global auto-retry: every query/mutation transparently retries on transient
// connection drops (Supabase free-tier pooler occasionally resets). A P1001
// means the query never reached the server, so retrying is safe.
const prisma = new PrismaClient().$extends({
    query: {
        $allOperations({ args, query }) {
            return _retry(() => query(args));
        },
    },
});

/**
 * Run an async query-thunk with automatic retry on transient connection
 * errors (P1001 "can't reach database", P1017 "server closed connection").
 * These happen under bursty load on pooled Supabase connections.
 */
async function withRetry(fn, retries = 3, delayMs = 400) {
    let lastErr;
    for (let i = 0; i <= retries; i++) {
        try {
            return await fn();
        } catch (e) {
            lastErr = e;
            const transient = e && (e.code === 'P1001' || e.code === 'P1017' || e.code === 'P2024');
            if (!transient || i === retries) throw e;
            await new Promise(r => setTimeout(r, delayMs * (i + 1)));
        }
    }
    throw lastErr;
}

/**
 * Run an array of thunks (() => Promise) with a bounded concurrency so a
 * burst of queries never overwhelms the pooled DB connection. Each thunk is
 * retried on transient errors. Returns results in the original order.
 */
async function runLimited(thunks, concurrency = 4) {
    const results = new Array(thunks.length);
    let next = 0;
    async function worker() {
        while (next < thunks.length) {
            const idx = next++;
            results[idx] = await withRetry(thunks[idx]);
        }
    }
    const workers = Array.from({ length: Math.min(concurrency, thunks.length) }, worker);
    await Promise.all(workers);
    return results;
}

module.exports = prisma;
module.exports.withRetry = withRetry;
module.exports.runLimited = runLimited;
