const { execSync } = require("child_process");
const os = require("os");

// Carpetas que nunca se abrevian, aunque quede en un segmento intermedio.
const PROTECTED_SEGMENTS = new Set([
  "desktop", "escritorio",
  "documents", "documentos",
  "downloads", "descargas",
  "pictures", "imagenes",
  "music", "musica",
  "videos",
  "onedrive",
  "proyectos", "projects",
]);

// Cuánto espacio se asume que ocupa el resto de la statusline (modelo,
// thinking, uso de sesion, timer, tokens) cuando no sabemos el ancho real.
const DEFAULT_BUDGET = 40;
const ASSUMED_REST_OF_LINE = 60;

function buildParts(path) {
  const homeDir = os.homedir();
  const useBackslash = path.includes("\\") && !path.includes("/");
  const sep = useBackslash ? "\\" : "/";
  let normalized = path;
  if (path.startsWith(homeDir)) {
    normalized = "~" + path.slice(homeDir.length);
  }
  const parts = normalized.split(/[\\/]+/).filter((p) => p !== "");
  return { parts, sep, normalized };
}

function joinParts(parts, sep, normalized) {
  if (normalized.startsWith("~")) return parts.join(sep);
  if (normalized.startsWith("/")) return sep + parts.join(sep);
  return parts.join(sep);
}

function abbreviatePath(path, terminalWidth) {
  const { parts, sep, normalized } = buildParts(path);

  const full = joinParts(parts, sep, normalized);

  const budget = typeof terminalWidth === "number"
    ? Math.max(20, terminalWidth - ASSUMED_REST_OF_LINE)
    : DEFAULT_BUDGET;

  if (full.length <= budget) return full;

  const abbreviated = parts.map((part, index) => {
    if (index === 0 || index === parts.length - 1) return part;
    if (PROTECTED_SEGMENTS.has(part.toLowerCase())) return part;
    if (part.startsWith(".") && part.length > 1) return "." + (part[1] ?? "");
    return part[0];
  });
  return joinParts(abbreviated, sep, normalized);
}

let input = "";
process.stdin.on("data", (chunk) => (input += chunk));
process.stdin.on("end", () => {
  let data;
  try {
    data = JSON.parse(input);
  } catch {
    process.exit(0);
  }
  const cwd = data.cwd;
  if (!cwd) process.exit(0);

  let insideGit = true;
  try {
    execSync("git rev-parse --is-inside-work-tree", {
      cwd,
      stdio: ["ignore", "ignore", "ignore"],
    });
  } catch {
    insideGit = false;
  }

  if (insideGit) {
    process.exit(0);
  }

  process.stdout.write(abbreviatePath(cwd, data.terminal_width));
});
