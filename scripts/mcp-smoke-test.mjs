#!/usr/bin/env node

import { spawn } from "node:child_process";
import process from "node:process";
import readline from "node:readline";

const [, , command, ...args] = process.argv;

if (!command) {
  console.error("Usage: scripts/mcp-smoke-test.mjs <command> [args...]");
  process.exit(2);
}

const child = spawn(command, args, {
  cwd: process.cwd(),
  env: process.env,
  stdio: ["pipe", "pipe", "pipe"],
});

const stderr = [];
child.stderr.setEncoding("utf8");
child.stderr.on("data", (chunk) => stderr.push(chunk));

let nextId = 1;
const pending = new Map();
const lines = readline.createInterface({ input: child.stdout });

lines.on("line", (line) => {
  if (line.trim() === "") {
    return;
  }

  let message;
  try {
    message = JSON.parse(line);
  } catch {
    return;
  }

  if (message.id === undefined) {
    return;
  }

  const waiter = pending.get(message.id);
  if (!waiter) {
    return;
  }

  pending.delete(message.id);
  if (message.error) {
    waiter.reject(new Error(JSON.stringify(message.error)));
  } else {
    waiter.resolve(message.result);
  }
});

function send(method, params) {
  const id = nextId++;
  const message = { jsonrpc: "2.0", id, method, params };

  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject });
    child.stdin.write(`${JSON.stringify(message)}\n`);
  });
}

function notify(method, params) {
  child.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", method, params })}\n`);
}

const timeout = setTimeout(() => {
  child.kill("SIGTERM");
  console.error("Timed out waiting for MCP server.");
  if (stderr.length > 0) {
    console.error(stderr.join(""));
  }
  process.exit(1);
}, 90_000);

try {
  await send("initialize", {
    protocolVersion: "2025-06-18",
    capabilities: {},
    clientInfo: {
      name: "stornaut-mcp-smoke-test",
      version: "1.0.0",
    },
  });
  notify("notifications/initialized", {});

  const result = await send("tools/list", {});
  const tools = result.tools.map((tool) => tool.name).sort();
  process.stdout.write(`${JSON.stringify(tools)}\n`);
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  if (stderr.length > 0) {
    console.error(stderr.join(""));
  }
  process.exitCode = 1;
} finally {
  clearTimeout(timeout);
  child.stdin.end();
  child.kill("SIGTERM");
}
