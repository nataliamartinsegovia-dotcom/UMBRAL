# UMBRAL

Registro personal de rendimiento. Se actualiza solo cada mañana con los datos
de WHOOP y permite añadir una anotación e imágenes de cada sesión.

Uso estrictamente personal. No está pensado para compartirse ni para que lo
use nadie más.

---

## Estructura

    index.html                    el panel
    admin.html                    formulario de nueva entrada
    scripts/fetch_whoop.py        sync diario (lo ejecuta GitHub Actions)
    scripts/bootstrap_auth.py     autorización inicial, se ejecuta una vez
    .github/workflows/daily.yml   el cron de cada mañana
    data/                         un JSON por día
    images/                       imágenes de las sesiones

---

## Puesta en marcha

### 1 · Repositorio
Crea un repo **privado** en GitHub llamado `umbral` y sube este contenido.

### 2 · App de WHOOP
En developer.whoop.com/dashboard crea una app. Anota Client ID y Client Secret.
Como Redirect URI usa `https://localhost:8080/whoop/callback` (WHOOP no acepta
`http://` a secas).

Scopes: `offline`, `read:recovery`, `read:cycles`, `read:sleep`,
`read:workout`, `read:profile`, `read:body_measurement`.

### 3 · Primer token
En tu ordenador:

    pip install requests
    python scripts/bootstrap_auth.py

Sigue las instrucciones. Al final te da los tres valores del paso siguiente.

### 4 · Secretos del repo
Settings → Secrets and variables → Actions:

    WHOOP_CLIENT_ID
    WHOOP_CLIENT_SECRET
    WHOOP_REFRESH_TOKEN
    GH_PAT

`GH_PAT` es un fine-grained token limitado a este repo, con permisos
`Contents: Read and write` y `Secrets: Read and write`. El workflow lo necesita
porque WHOOP invalida el refresh token cada vez que se usa, así que hay que
guardar el nuevo en cada ejecución.

### 5 · GitHub Pages
Settings → Pages → Deploy from a branch → main → / (root)

> Con cuenta gratuita, Pages sobre un repo privado se publica en una URL
> pública aunque el código sea privado. Si eso te incomoda, dímelo y lo
> montamos de otra forma.

### 6 · Ajustes
- La hora del sync está en `.github/workflows/daily.yml` (`0 8 * * *` = 08:00 UTC).
  WHOOP necesita que el ciclo de sueño haya cerrado para tener datos de recovery.
- La fecha de la competición y el umbral de recuperación están arriba del todo
  del `<script>` en `index.html`:

      const RACE_DATE = '2026-12-12';
      const THRESHOLD = 67;

### 7 · Probar
Pestaña Actions → "Sincronización diaria WHOOP" → Run workflow.

---

## Uso diario

    Panel     https://<usuario>.github.io/umbral/
    Entrada   https://<usuario>.github.io/umbral/admin.html

---

## Notas

- WHOOP no tiene tipo de actividad "calistenia". Las sesiones del box
  aparecerán como Functional Fitness, HIIT o Weightlifting según cómo las
  registres. Usa la anotación para el contexto real.
- Las imágenes se guardan en el propio repo. Si el volumen crece mucho
  (>1 GB) conviene mover a almacenamiento externo.
