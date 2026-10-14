// Chơi thử bản Web trong Chrome qua DevTools Protocol (Node 24 có sẵn WebSocket).
// Dùng: node tools/checks/web_play.mjs <url index.html> <thư mục ảnh> [perf]
//   mặc định: vào menu -> Chơi mới (Enter) -> đi (D) -> bắn (chuột trái), chụp ảnh từng bước, fail nếu console có lỗi.
//   perf: mở <url>?shot=perf, chờ dòng "PERF ..." trong console (thành phố tối đa người/xe + 3 sao).
//   persist: Chơi mới -> tải lại trang -> đọc IndexedDB tìm save.json, chụp menu (phải có "Chơi tiếp").
import { spawn } from "node:child_process";
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const [url, outDir, mode] = process.argv.slice(2);
const PORT = 9300 + (process.pid % 500); // cổng riêng mỗi lần chạy, tránh đụng Chrome vừa tắt
const BOOT_MS = 25000; // --virtual-time-budget không chờ được bước biên dịch WASM: chờ thời gian thực
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const profile = mkdtempSync(join(tmpdir(), "nh-chrome-"));
// NH_HEADED=1: mở cửa sổ Chrome thật (dùng GPU của máy) thay vì headless (thường rơi về SwiftShader).
const headless = process.env.NH_HEADED ? [] : ["--headless=new"];
const chrome = spawn("google-chrome", [
  ...headless, "--ignore-gpu-blocklist", `--remote-debugging-port=${PORT}`, `--user-data-dir=${profile}`,
  "--window-size=1280,720", "--no-first-run", "--autoplay-policy=no-user-gesture-required",
  "--enable-unsafe-swiftshader", "about:blank",
], { stdio: "ignore" });

let ws;
let nextId = 1;
const pending = new Map();
const consoleLines = [];

function send(method, params = {}) {
  const id = nextId++;
  ws.send(JSON.stringify({ id, method, params }));
  return new Promise((resolve, reject) => pending.set(id, { resolve, reject, method }));
}

async function connect() {
  for (let i = 0; i < 50; i++) {
    try {
      const list = await (await fetch(`http://127.0.0.1:${PORT}/json/list`)).json();
      const page = list.find((t) => t.type === "page");
      if (page) return page.webSocketDebuggerUrl;
    } catch { /* Chrome chưa sẵn sàng */ }
    await sleep(200);
  }
  throw new Error("không kết nối được Chrome DevTools");
}

async function shot(name) {
  const { data } = await send("Page.captureScreenshot", { format: "png" });
  const path = join(outDir, name);
  writeFileSync(path, Buffer.from(data, "base64"));
  console.log(`SHOT ${path}`);
}

async function key(code, text, holdMs = 80) {
  const vk = { Enter: 13, KeyD: 68, KeyW: 87, KeyE: 69 }[code];
  const base = { code, key: text, windowsVirtualKeyCode: vk, nativeVirtualKeyCode: vk };
  await send("Input.dispatchKeyEvent", { type: "keyDown", ...base });
  await sleep(holdMs);
  await send("Input.dispatchKeyEvent", { type: "keyUp", ...base });
}

async function click(x, y) {
  const base = { x, y, button: "left", clickCount: 1 };
  await send("Input.dispatchMouseEvent", { type: "mouseMoved", x, y });
  await send("Input.dispatchMouseEvent", { type: "mousePressed", ...base });
  await sleep(60);
  await send("Input.dispatchMouseEvent", { type: "mouseReleased", ...base });
}

async function main() {
  ws = new WebSocket(await connect());
  await new Promise((r) => ws.addEventListener("open", r));
  ws.addEventListener("message", (ev) => {
    const msg = JSON.parse(ev.data);
    if (msg.id && pending.has(msg.id)) {
      const p = pending.get(msg.id);
      pending.delete(msg.id);
      msg.error ? p.reject(new Error(`${p.method}: ${msg.error.message}`)) : p.resolve(msg.result);
    } else if (msg.method === "Runtime.consoleAPICalled") {
      consoleLines.push(`[${msg.params.type}] ` + msg.params.args.map((a) => a.value ?? a.description ?? "").join(" "));
    } else if (msg.method === "Runtime.exceptionThrown") {
      consoleLines.push("[exception] " + msg.params.exceptionDetails.text);
    }
  });
  await send("Runtime.enable");
  await send("Page.enable");
  await send("Emulation.setDeviceMetricsOverride", { width: 1280, height: 720, deviceScaleFactor: 1, mobile: false });

  if (mode === "perf") {
    await send("Page.navigate", { url: `${url}?shot=perf` });
    for (let i = 0; i < 120 && !consoleLines.some((l) => l.includes("PERF ")); i++) await sleep(1000);
    const line = consoleLines.find((l) => l.includes("PERF "));
    const gl = await send("Runtime.evaluate", { expression: "(() => { const g = document.createElement('canvas').getContext('webgl2'); const i = g && g.getExtension('WEBGL_debug_renderer_info'); return i ? g.getParameter(i.UNMASKED_RENDERER_WEBGL) : 'không rõ'; })()", returnByValue: true });
    console.log(line ?? "PERF: không nhận được kết quả");
    console.log("renderer: " + gl.result.value);
    await shot("web_perf.png");
    return line ? 0 : 1;
  }

  if (mode === "persist") {
    await send("Page.navigate", { url });
    await sleep(BOOT_MS);
    await click(640, 360);
    await key("Enter", "Enter");
    await sleep(6000);
    await send("Page.reload");
    await sleep(BOOT_MS);
    await shot("web_persist_menu.png");
    const found = await send("Runtime.evaluate", { awaitPromise: true, returnByValue: true, expression: `new Promise((ok) => {
      const req = indexedDB.open("/userfs");
      req.onerror = () => ok("không mở được IndexedDB /userfs");
      req.onsuccess = () => {
        const tx = req.result.transaction("FILE_DATA", "readonly");
        const keys = tx.objectStore("FILE_DATA").getAllKeys();
        keys.onsuccess = () => ok(keys.result.filter((k) => String(k).endsWith("save.json")).join(", ") || "không có save.json");
      };
    })` });
    console.log("IndexedDB: " + found.result.value);
    return String(found.result.value).includes("save.json") && !String(found.result.value).startsWith("không") ? 0 : 1;
  }

  await send("Page.navigate", { url });
  await sleep(BOOT_MS);
  await shot("web_menu.png");
  await click(640, 360); // trang cần focus để nhận phím
  await key("Enter", "Enter");
  await sleep(4000);
  await shot("web_city.png");
  await key("KeyD", "d", 1500);
  for (let i = 0; i < 6; i++) await click(1100, 360);
  await sleep(150);
  await shot("web_play.png");
  const errors = consoleLines.filter((l) => /ERROR|exception|\[error\]/i.test(l));
  console.log(`console: ${consoleLines.length} dòng, ${errors.length} lỗi`);
  errors.slice(0, 10).forEach((e) => console.log("  " + e));
  return errors.length === 0 ? 0 : 1;
}

let code = 1;
try {
  code = await main();
} catch (e) {
  console.log("WEB: lỗi " + e.message);
} finally {
  ws?.close();
  chrome.kill();
  await sleep(300);
  rmSync(profile, { recursive: true, force: true });
}
console.log(code === 0 ? "WEB: PASS" : "WEB: FAIL");
process.exit(code);
