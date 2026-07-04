export function buildGreeting(name: string): string {
  const trimmed = name.trim();
  return `Hello, ${trimmed.length > 0 ? trimmed : "world"}!`;
}

Deno.serve((req: Request) => {
  const url = new URL(req.url);
  const name = url.searchParams.get("name") ?? "";

  return new Response(
    JSON.stringify({ message: buildGreeting(name) }),
    { headers: { "Content-Type": "application/json" } },
  );
});
