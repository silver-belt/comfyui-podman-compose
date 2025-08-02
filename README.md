# comfyui-podman-compose
Run ComfyUI in podman compose behind an `nginx` reverse proxy that
exposes the service with HTTPS and basic authentication on port `8443`.

## Setup

1. Create a password file (example user `user` with password `changeme`):

   ```sh
   printf "user:$(openssl passwd -apr1 'changeme')\n" > nginx/htpasswd
   ```

2. Place a TLS certificate and key in `nginx/certs/server.crt` and
   `nginx/certs/server.key`. A self-signed certificate for local testing
   can be generated with:

   ```sh
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
     -keyout nginx/certs/server.key \
     -out nginx/certs/server.crt \
     -subj "/CN=localhost"
   ```

3. Start the stack:

   ```sh
   podman-compose up
   ```

ComfyUI is then available at <https://localhost:8443> and protected by
the credentials in `nginx/htpasswd`. The certificate and password file
are ignored by Git for security and must be created locally.
