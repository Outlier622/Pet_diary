# Diary Backend (API v1)

A minimal FastAPI backend for a pet diary application.

## Features

- JWT authentication
- User profile management
- Pets CRUD
- Records (timeline) CRUD
- Media attachment to records
- Idempotent write APIs
- Unified response envelope

## Tech Stack

- FastAPI
- SQLAlchemy (async)
- PostgreSQL
- JWT (Bearer)
- Docker (DB)

## Run Locally

```bash
uvicorn app.main:app --reload
