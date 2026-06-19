// Supabase Edge Function: "manage-employee"
// Nur für die Führungskraft (sie muss eingeloggt sein – ihr Token wird geprüft).
// Aktionen: Mitarbeiter anlegen, Zugangscode zurücksetzen, aktiv/inaktiv, löschen.
//
// Einrichten im Dashboard:
//   Edge Functions -> Create a new function -> Name: manage-employee
//   -> diesen Code einfügen -> Deploy.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

    // Aufrufer (Führungskraft) aus dem mitgeschickten Token bestimmen
    const token = (req.headers.get("Authorization") || "").replace("Bearer ", "");
    const { data: userData } = await admin.auth.getUser(token);
    const fk = userData?.user;
    if (!fk) return json({ error: "Nicht angemeldet." }, 401);

    const body = await req.json();
    const { action, practice_id, employee_id, name, position, code, active } = body;

    // Hilfsfunktion: Gehört die Praxis dieser Führungskraft?
    async function ownsPractice(pid: string) {
      const { data } = await admin.from("practices").select("id").eq("id", pid).eq("owner", fk.id).maybeSingle();
      return !!data;
    }
    // Praxis-Id zu einem Mitarbeiter ermitteln und Eigentum prüfen
    async function ownsEmployee(eid: string) {
      const { data } = await admin.from("employees").select("id, practice_id, auth_uid").eq("id", eid).maybeSingle();
      if (!data) return null;
      return (await ownsPractice(data.practice_id)) ? data : null;
    }

    if (action === "create") {
      if (!(await ownsPractice(practice_id))) return json({ error: "Keine Berechtigung." }, 403);
      if (!name || !code) return json({ error: "Name und Zugangscode nötig." }, 400);
      // 1) Mitarbeiterzeile anlegen, um die Id zu erhalten
      const { data: emp, error: e1 } = await admin
        .from("employees").insert({ practice_id, name: String(name).trim(), position: position || null }).select().single();
      if (e1) return json({ error: e1.message }, 400);
      // 2) Schattenkonto mit dem Zugangscode als Passwort anlegen
      const email = `emp.${emp.id}@praxis.local`;
      const { data: created, error: e2 } = await admin.auth.admin.createUser({
        email, password: String(code).trim(), email_confirm: true,
      });
      if (e2) { await admin.from("employees").delete().eq("id", emp.id); return json({ error: e2.message }, 400); }
      // 3) Konto-Id in der Mitarbeiterzeile vermerken
      await admin.from("employees").update({ auth_uid: created.user.id }).eq("id", emp.id);
      return json({ ok: true, employee: { ...emp, auth_uid: created.user.id } });
    }

    if (action === "reset_code") {
      const emp = await ownsEmployee(employee_id);
      if (!emp) return json({ error: "Keine Berechtigung." }, 403);
      if (!code) return json({ error: "Neuer Zugangscode nötig." }, 400);
      if (emp.auth_uid) await admin.auth.admin.updateUserById(emp.auth_uid, { password: String(code).trim() });
      return json({ ok: true });
    }

    if (action === "set_active") {
      const emp = await ownsEmployee(employee_id);
      if (!emp) return json({ error: "Keine Berechtigung." }, 403);
      await admin.from("employees").update({ active: !!active }).eq("id", employee_id);
      return json({ ok: true });
    }

    if (action === "delete") {
      const emp = await ownsEmployee(employee_id);
      if (!emp) return json({ error: "Keine Berechtigung." }, 403);
      if (emp.auth_uid) await admin.auth.admin.deleteUser(emp.auth_uid);
      await admin.from("employees").delete().eq("id", employee_id);
      return json({ ok: true });
    }

    return json({ error: "Unbekannte Aktion." }, 400);
  } catch (e) {
    return json({ error: "Serverfehler: " + (e as Error).message }, 500);
  }
});
