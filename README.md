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
netlify.toml          publica la carpeta tal cual, en Netlify
vercel.json           lo mismo, en Vercel: cada uno lee solo el suyo
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
| `members` | registro de quién entró, su equipo y quién es docente     |
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

## Quién puede entrar

**Cualquiera con una cuenta de Google**, o con acceso a cualquier casilla de
mail. No hay lista de invitados que mantener: la primera vez que alguien
inicia sesión, un trigger sobre `auth.users` le crea la fila en `members`
con `is_admin = false`.

Eso significa que **cualquiera que encuentre la URL puede entrar y cargar
dados en los seis equipos**. Es deliberado, para no tener que cargar la lista
del curso antes de cada clase, pero conviene tenerlo presente: si el ejercicio
se hace en vivo, alguien de afuera podría escribir sobre los datos.

El alta automática nunca otorga el rol de docente: entra todo el mundo como
alumno. De ahí en más, **rol y equipo se manejan desde la pestaña Admin**, en
la tarjeta "Quién juega en cada equipo": una fila por persona, con un
desplegable para el rol y otro para el equipo. No hace falta SQL.

Dos detalles de esa tarjeta:

- **Tu propia fila tiene el rol trabado.** Si el único docente se degrada a sí
  mismo, no queda nadie que pueda devolverle el permiso desde la página y hay
  que volver al SQL Editor. El resto de los docentes sí se pueden degradar.
- **Nombrar a un docente pide confirmación**, porque ese rol puede ocultarle
  cosas al curso, borrar los dados de los seis equipos, corregir dados ya
  cargados y nombrar a más docentes.

El único momento en que hace falta SQL es el primero, para nombrarte docente a
vos, porque todavía no hay ningún docente que pueda hacerlo desde la página.
Eso sale del bloque final de `supabase/setup.sql`. Después:

```sql
-- ver quién entró, con qué rol y en qué equipo
select email, is_admin, team, nota from public.members order by email;

-- limpiar el registro entre cursadas: se dan de alta solos de nuevo
delete from public.members where not is_admin;
```

### Volver a cerrarlo a una lista

Si alguna vez querés el comportamiento anterior — solo entra quien vos
cargaste — cambiá el cuerpo de `is_member()` en `supabase/setup.sql` por la
versión que está comentada justo arriba, y volvé a correr el archivo. El
trigger puede quedar: se vuelve inofensivo, porque la fila que crea ya no
alcanza para pasar.

---

## Cómo se usa en clase

Cada equipo abre la página, entra con su mail y elige su pestaña. En cada
vuelta tiran el dado por estación y cargan el número: al escribirlo, el foco
salta solo a la estación siguiente de la misma vuelta, que es el orden real
del juego. Movidas, inventario y desviación se calculan solos y se ven en
todas las computadoras al instante.

Además de la grilla, cada equipo ve una tabla de **capacidad y utilización por
estación**: cuánta capacidad sacó en dados, cuánta usó de verdad, cuánto quedó
frenado y qué porcentaje aprovechó. Ahí se ve el nudo del ejercicio: la
estación 1 siempre marca 100 %, porque nunca espera material, y de la segunda
en adelante el porcentaje cae. Esa capacidad perdida no se recupera después.

La pestaña **Admin** aparece únicamente para quien tenga `is_admin = true`.
Tiene seis interruptores —indicadores, gráfico, fila de desviación, capacidad
por estación, nota de fórmulas y bajada del título— más la tabla comparativa
de los seis equipos, que arranca apagada. Cada uno apaga y prende esa parte en
todas las pantallas a la vez. El docente igual ve los números completos en su
propia tabla comparativa.

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

## Un dado cargado no se toca

Igual que en la planilla original: una vez que se anota una tirada, esa celda
queda congelada. No se puede corregir ni borrar. Si se pudiera repetir una
tirada mala, el ejercicio dejaría de mostrar lo que tiene que mostrar.

El docente sí puede cambiarlas — es quien arregla los errores de carga — y es
el único que ve el botón "Limpiar este equipo".

La regla está en un trigger de la base (`enforce_dados_inmutables`), no solo en
el navegador: aunque alguien fuerce el campo desde la consola, el `update` se
rechaza. En la página aparece "Ese dado ya estaba cargado" y la grilla vuelve a
lo que dice el servidor.

---

## Qué protege qué

| Capa | Para qué sirve |
|------|----------------|
| Login por Google o mail (Supabase Auth) | Identifica a la persona. Entrar está abierto a cualquiera |
| Tabla `members` | Registra a quien entra y decide quién es docente |
| Políticas RLS | Aplican esa decisión **del lado del servidor** |
| Trigger `enforce_dados_inmutables` | Impide cambiar o borrar un dado ya cargado, salvo el docente |
| `config.js` | Solo dice a qué proyecto conectarse; no es un secreto |

La pestaña Admin no se esconde solo en el navegador: aunque alguien la fuerce
desde la consola, la base rechaza la escritura sobre `config` si su mail no
tiene `is_admin`.
