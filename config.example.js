// 1. Diese Datei kopieren und in "config.js" umbenennen.
// 2. Die zwei Werte aus dem Supabase-Dashboard eintragen
//    (Project Settings -> API: "Project URL" und "anon public").
// Diese Werte dürfen öffentlich sein – der Schutz läuft serverseitig (RLS).
// Den "service_role"-Key NIEMALS hier eintragen!

window.APP_CONFIG = {
  SUPABASE_URL: "https://DEINPROJEKT.supabase.co",
  SUPABASE_ANON_KEY: "DEIN-ANON-PUBLIC-KEY",
};
