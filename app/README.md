# NTI Full Stack App

This project includes:
- Frontend: static HTML/JS app served by Nginx
- Backend: Node.js + Express API
- Database: MySQL 8

## Run locally

```bash
docker compose up --build
```

To start the optional local SonarQube instance as well, run `docker compose --profile quality up --build`. SonarQube is bound to `127.0.0.1:9000`; the default local DB password is for development only.

Then open:
- Frontend: http://localhost
- Backend: http://localhost:3001/api/health
- Adminer: http://localhost:8081

## Default database values
- DB name: appdb
- DB user: appuser
- DB password: apppass

## Notes
- The backend connects to the MySQL service using the Docker network name `db`
- The frontend calls the backend through port 3001
