/* ============================================================
   CONFIGURACIÓN  ← lo único que tenés que editar

   Los dos valores están en Supabase:
     Project Settings → API
       - Project URL          → SUPABASE_URL
       - anon / public key    → SUPABASE_ANON_KEY

   Esta clave es pública a propósito: viaja en el HTML y
   cualquiera puede verla. Lo que protege los datos son las
   políticas RLS de supabase/setup.sql, no la clave.
   NUNCA pongas acá la service_role key.

   Si dejás los dos campos vacíos, la página funciona igual
   pero guarda solo en esta computadora, sin login.
   ============================================================ */
var SUPABASE_URL      = "https://bqowrafdshlkgaszbyvc.supabase.co";
var SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJxb3dyYWZkc2hsa2dhc3pieXZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk0MTIzODEsImV4cCI6MjEwNDk4ODM4MX0.UZO2RtdQ8WFH6Bq1DqZociCVgLlHC5aaSodkBcv2aa0";
