// Supabase Edge Function: "employee-login"
// Meldet einen Mitarbeiter mit Praxis-Code + Name + Zugangscode an und gibt
// eine Sitzung (Session) zurück. Kein Login der Führungskraft nötig.
//
// Einrichten im Dashboard:
//   Edge Functions -> Create a new function -> Name: employee-login
//   -> diesen Code einfügen -> Deploy.
// Die Variablen SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY
// stellt Supabase automatisch bereit.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const { join_code, name, code } = await req.json();
    if (!join_code || !name || !code) {
      return json({ error: "Praxis-Code, Name und Zugangscode sind nötig." }, 400);
    }

    const url = Deno.env.get("SUPABASE_URL")!;
    const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

    // Praxis über den Praxis-Code finden
    const { data: practice } = await admin
      .from("practices")
      .select("id")
      .eq("join_code", String(join_code).trim().toUpperCase())
      .maybeSingle();
    if (!practice) return json({ error: "Praxis-Code nicht gefunden." }, 404);

    // Mitarbeiter über den Namen finden (eindeutig je Praxis)
    const { data: emps } = await admin
      .from("employees")
      .select("id")
      .eq("practice_id", practice.id)
      .eq("active", true)
      .ilike("name", String(name).trim());
    if (!emps || emps.length === 0) return json({ error: "Name nicht gefunden." }, 404);
    if (emps.length > 1) return json({ error: "Name nicht eindeutig – bitte an die Führungskraft wenden." }, 409);

    // Mit dem Schattenkonto (E-Mail aus der Mitarbeiter-Id, Passwort = Zugangscode) anmelden
    const email = `emp.${emps[0].id}@praxis.local`;
    const anon = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!);
    const { data: session, error } = await anon.auth.signInWithPassword({
      email,
      password: String(code).trim(),
    });
    if (error || !session?.session) return json({ error: "Zugangscode falsch." }, 401);

    return json({
      access_token: session.session.access_token,
      refresh_token: session.session.refresh_token,
    });
  } catch (e) {
    return json({ error: "Serverfehler: " + (e as Error).message }, 500);
  }
});
