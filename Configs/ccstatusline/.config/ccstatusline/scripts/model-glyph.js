let input = "";
process.stdin.on("data", (chunk) => (input += chunk));
process.stdin.on("end", () => {
  let data;
  try {
    data = JSON.parse(input);
  } catch {
    process.exit(0);
  }

  const id = (data.model?.id || "").toLowerCase();
  const displayName = (data.model?.display_name || "").toLowerCase();
  const combined = `${id} ${displayName}`;

  let glyph;
  if (combined.includes("opus")) glyph = "◆";
  else if (combined.includes("sonnet")) glyph = "☉";
  else if (combined.includes("haiku")) glyph = "◇";
  else glyph = "◈";

  process.stdout.write(glyph);
});
