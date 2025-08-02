Place your TLS certificate as server.crt and key as server.key in this directory.
You can generate a self-signed certificate for local testing with:

openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout server.key -out server.crt -subj "/CN=localhost"
These files are excluded from version control for security.
