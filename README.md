# Línea de mates

Simulador del ejercicio de dados de **Teoría de las Restricciones** (Unidad 4).
Cinco estaciones en serie, cinco vueltas, un dado por estación y vuelta. Seis
equipos que trabajan al mismo tiempo desde computadoras distintas, y una
pestaña de docente para ocultar las estadísticas hasta el momento de la
discusión.

Es una página estática: un `index.html`, sin build, sin dependencias que
instalar. Los datos compartidos y el login los pone Supabase.

---

## Estructura

```
index.html            la aplicación entera (HTML + CSS + JS)
config.js             tus dos valores de Supabase  ← lo único que editás
supabase/setup.sql    tablas, permisos y realtime, para pegar una sola vez
netlify.toml          publica la carpeta tal cual
```

---

## Puesta en marcha

### 1. Crear el proyecto en Supabase

En [supabase.com](https://supabase.com) creá una cuenta y un proyecto nuevo.
Elegí la región más cercana. Tarda un par de minutos en levantar.

### 2. Cargar el esquema

En el panel del proyecto, entrá a **SQL Editor** y pegá todo el contenido de
`supabase/setup.sql`. Antes de ejecutarlo, bajá hasta el bloque final y
cambiá `cambiame@tumail.com` por tu mail, con `is_admin = true`. Ejecutá.

Eso crea tres tablas:

| tabla     | qué guarda                                              |
|-----------|---------------------------------------------------------|
| `members` | quién puede entrar, y quién es docente                  |
| `teams`   | seis filas, una por equipo, con la matriz de dados      |
| `config`  | una fila: qué estadísticas ve el curso                  |

### 3. Conectar la página

En Supabase, **Project Settings → API**, copiá:

- **Project URL** → `SUPABASE_URL`
- **anon public key** → `SUPABASE_ANON_KEY`

y pegalos en `config.js`.

> La clave `anon` es pública a propósito: viaja en el HTML y cualquiera puede
> verla. Lo que protege los datos son las políticas RLS de `setup.sql`, no la
> clave. La `service_role` key **nunca** va en estos archivos.

### 4. Autorizar la URL de retorno

En Supabase, **Authentication → URL Configuration**:

- **Site URL**: la URL final del sitio (por ejemplo `https://linea-de-mates.netlify.app`)
- **Redirect URLs**: agregá esa misma URL

Sin esto, el enlace que llega por mail no devuelve a la página.

### 5. Publicar

**Netlify**: en [app.netlify.com](https://app.netlify.com), "Add new site →
Deploy manually" y arrastrá la carpeta. O conectá el repositorio de GitHub y
dejá los valores por defecto (no hay comando de build; la carpeta a publicar
es la raíz).

**Vercel**: importá el repositorio y elegí framework "Other". Sin comando de
build, output directory `.`.

Cualquiera de los dos te da la URL que va en el paso 4.

---

## Manejar la lista del curso

Todo pasa por la tabla `members`. Desde el SQL Editor:

```sql
-- sumar gente
insert into public.members (email, is_admin, nota) values
  ('alumno@ejemplo.com', false, 'Equipo 3')
on conflict (email) do update set is_admin = excluded.is_admin;

-- ver la lista
select email, is_admin, nota from public.members order by email;

-- sacar a alguien
delete from public.members where email = 'alguien@ejemplo.com';
```

Los mails van **en minúscula**. Quien no esté en la tabla puede iniciar
sesión, pero no ve absolutamente nada: las políticas RLS le devuelven cero
filas y la página se lo dice.

Para sumar otro docente, `is_admin = true`.

---

## Cómo se usa en clase

Cada equipo abre la página, entra con su mail y elige su pestaña. En cada
vuelta tiran el dado por estación y cargan el número: al escribirlo, el foco
salta solo a la estación siguiente de la misma vuelta, que es el orden real
del juego. Movidas, inventario y desviación se calculan solos y se ven en
todas las computadoras al instante.

La pestaña **Admin** aparece únicamente para quien tenga `is_admin = true`.
Tiene tres interruptores —indicadores, gráfico y fila de desviación— que
apagan y prenden esas partes en todas las pantallas a la vez. El docente
igual ve los números completos en su tabla comparativa de los seis equipos.

---

## Las fórmulas

Son las de la planilla original:

```
movidas    = MÍN(dado, inventario previo + movidas de la estación anterior)
inventario = inventario previo + entrada − movidas
desviación = movidas − 3,5 + desviación de la vuelta anterior
```

La estación 1 nunca espera material, así que mueve exactamente lo que marca
su dado y su inventario es siempre cero. El 3,5 es el valor esperado de un
dado: de ahí sale la producción teórica de 17,5 kits en cinco vueltas, que la
línea nunca alcanza.

---

## Modo local

Si `config.js` queda con los dos valores vacíos, la página funciona igual:
sin login, sin sincronización, guardando en el navegador de esa computadora,
y con la pestaña Admin siempre a la vista. Sirve para probar el archivo
abriéndolo con doble clic antes de publicar nada.

---

## Qué protege qué

| Capa | Para qué sirve |
|------|----------------|
| Login por mail (Supabase Auth) | Identifica a la persona |
| Tabla `members` | Decide quién entra y quién es docente |
| Políticas RLS | Aplican esa decisión **del lado del servidor** |
| `config.js` | Solo dice a qué proyecto conectarse; no es un secreto |

La pestaña Admin no se esconde solo en el navegador: aunque alguien la fuerce
desde la consola, la base rechaza la escritura sobre `config` si su mail no
tiene `is_admin`.
