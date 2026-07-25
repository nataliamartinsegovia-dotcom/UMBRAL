"""
Run this ONCE, locally on your own computer (not in GitHub Actions), to get
the first refresh token. After that, the daily workflow rotates it on its own.

Usage:
  pip install requests
  python scripts/bootstrap_auth.py

You'll need the Client ID / Secret / Redirect URI from your app at
developer.whoop.com/dashboard.
"""
import requests
import urllib.parse
import webbrowser

CLIENT_ID = input("WHOOP Client ID: ").strip()
CLIENT_SECRET = input("WHOOP Client Secret: ").strip()
REDIRECT_URI = input("Redirect URI (as registered in the WHOOP dashboard, e.g. https://localhost:8080/whoop/callback): ").strip()

SCOPES = "offline read:recovery read:cycles read:sleep read:workout read:profile read:body_measurement"

auth_url = "https://api.prod.whoop.com/oauth/oauth2/auth?" + urllib.parse.urlencode({
    "client_id": CLIENT_ID,
    "redirect_uri": REDIRECT_URI,
    "response_type": "code",
    "scope": SCOPES,
    "state": "bootstrap",
})

print("\nAbriendo el navegador para autorizar la app. Inicia sesión y acepta.")
print("Si no se abre solo, copia esta URL:\n", auth_url, "\n")
webbrowser.open(auth_url)

redirected_url = input("Pega aquí la URL completa a la que te redirigió después de aceptar: ").strip()
parsed = urllib.parse.urlparse(redirected_url)
code = urllib.parse.parse_qs(parsed.query).get("code", [None])[0]

if not code:
    raise SystemExit("No se encontró el parámetro 'code' en esa URL. Revisa e inténtalo de nuevo.")

resp = requests.post("https://api.prod.whoop.com/oauth/oauth2/token", data={
    "grant_type": "authorization_code",
    "code": code,
    "client_id": CLIENT_ID,
    "client_secret": CLIENT_SECRET,
    "redirect_uri": REDIRECT_URI,
})
resp.raise_for_status()
tokens = resp.json()

print("\n¡Listo! Guarda esto como secretos del repo en GitHub (Settings → Secrets and variables → Actions):\n")
print(f"WHOOP_CLIENT_ID     = {CLIENT_ID}")
print(f"WHOOP_CLIENT_SECRET = {CLIENT_SECRET}")
print(f"WHOOP_REFRESH_TOKEN = {tokens['refresh_token']}")
print("\n(El access_token de ahora no hace falta guardarlo — el workflow pide uno nuevo cada vez.)")
