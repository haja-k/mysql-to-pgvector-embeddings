## mysql-to-pgvector-embeddings (PVRA API)

A compact FastAPI service that syncs rows from a MySQL table into a PostgreSQL table with pgvector, generates embeddings via an external embedding service, and exposes vector search endpoints. This README replaces the previous merged/duplicated content and adds guidance for configuring external embedding providers.

Table of contents
- Highlights
- Quick start (local & Docker)
- Configuration / .env
- Embedding provider guide (OpenAI, Hugging Face, self-hosted)
- Database schema
- How it works
- API examples
- Next steps & extras

Highlights
- Endpoints in `app.py`:
  - `GET /healthcheck` — status
  - `GET /documents` — read documents from MySQL
  - `POST /documents/sync-embeddings` — migrate new rows and store embeddings in pgvector
  - `POST /search` — structured similarity search results
  - `POST /search-simple` — Dify-friendly text + sources
- Async MySQL reads (`aiomysql`), PostgreSQL access (`psycopg2`).
- Calls an external embedding HTTP API. The code pads vectors to 4096 when necessary.
- Uses `migration_tracker` to avoid reprocessing rows.
- Docker-ready (Dockerfile + docker-compose provided).

Quick start (local)
1. Add a `.env` file (see `.env.example`).
2. Install dependencies:

```bash
python -m pip install -r requirements.txt
```

3. Run the app (development):

```bash
uvicorn app:app --reload --host 0.0.0.0 --port 5000
```

Quick start (Docker)
1. Create `.env` and set DB + embedding values.
2. Build & run with compose:

```bash
docker-compose up --build -d
```

Configuration / .env
Create a `.env` (or copy `.env.example`) and set the following:

```env
# MySQL
DB_HOST=localhost
DB_PORT=3306
DB_USER=your_mysql_user
DB_PASSWORD=your_mysql_password
DB_NAME=db_ses

# PostgreSQL
PG_HOST=localhost
PG_PORT=5432
PG_USER=your_pg_user
PG_PASSWORD=your_pg_password
PGVECTOR_DB_NAME=your_pgvector_db
PG_DB_NAME=your_pg_db

# Embedding service (HTTP API)
EMBEDDING_MODEL_HOST=https://your-embed-host
EMBEDDING_API_KEY=your_api_key
EMBEDDING_MODEL_NAME=your_model_name

# Optional: change expected vector dimension if you adapt the code
# (app.py pads to 4096 by default)
EMBEDDING_EXPECTED_DIM=4096

APP_DEBUG=false
```

Embedding provider guide
------------------------
This app delegates embedding generation to an HTTP embedding API. The code expects the provider to expose an endpoint that returns an embedding array (the code expects the first element at `response.json()['data'][0]['embedding']` but you can adapt it).

Key notes:
- The app pads shorter embeddings to the configured expected dimension (default 4096). If your provider returns different dimensions, either update `EMBEDDING_EXPECTED_DIM` or modify `get_embeddings()` in `app.py`.
- For production, prefer batching multiple inputs per request if your provider supports it — it's faster and cheaper.

Examples

1) OpenAI-compatible API (or OpenAI itself)

Set env vars:

```env
EMBEDDING_MODEL_HOST=https://api.openai.com/v1
EMBEDDING_API_KEY=sk-...
EMBEDDING_MODEL_NAME=text-embedding-3-large
```

Typical request (the code sends JSON {"model":..., "input": text} to `${EMBEDDING_MODEL_HOST}/embeddings`). The response shape expected in `app.py` is the OpenAI-style `{"data":[{"embedding": [...]}, ...]}`.

2) Hugging Face Inference API (example)

Set env vars:

```env
EMBEDDING_MODEL_HOST=https://api-inference.huggingface.co/models/<your-model>
EMBEDDING_API_KEY=hf_...
EMBEDDING_MODEL_NAME=<model-name>  # optional here; the model is in the URL
```

Hugging Face inference returns embeddings in different JSON shapes depending on the model and client. If you use HF, modify `get_embeddings()` to parse the returned JSON accordingly (e.g., HF may return a flat array or a base64 blob depending on the model).

3) Self-hosted / custom embedding server

If you run a local embedding server (Qwen, Llama 2, etc.), point `EMBEDDING_MODEL_HOST` to your server (e.g., `http://localhost:8000`) and ensure the endpoint `/embeddings` accepts the same JSON payload or update `get_embeddings()` to match your server's contract.

Troubleshooting tips for providers
- If embeddings are missing or wrong-length, check logs — the app pads but you may prefer to raise an error.
- Monitor rate limits and implement retries/backoff if your provider throttles.
- For large syncs, batch inputs to reduce HTTP requests.

Database schema (summary)
- Source MySQL table (example `tbl_genie_genie`) with: id, genie_question, genie_answer, genie_questiondate, genie_sourcelink.
- PostgreSQL `genie_documents`: id, question, answer, link, date, question_embedding VECTOR(4096), answer_embedding VECTOR(4096).
- `migration_tracker` to store last migrated id.

How it works (brief)
- `documents/sync-embeddings` reads new rows from MySQL (id > last migrated) and inserts into `genie_documents` (skipping duplicate questions).
- For each row the service calls the embedding API for question and answer, pads the vectors if needed, and updates `question_embedding` and `answer_embedding` in Postgres.
- Search endpoints compute similarity using pgvector (`1 - (question_embedding <=> %s::vector)`) and return ranked results.

API examples
- Health check:

```bash
curl http://localhost:5000/healthcheck
```

- Simple search:

```bash
curl -X POST http://localhost:5000/search-simple \
  -H 'Content-Type: application/json' \
  -d '{"query":"example query","limit":5,"similarity_threshold":0.7}'
```

- Sync embeddings:

```bash
curl -X POST http://localhost:5000/documents/sync-embeddings
```

Next steps & extras
- Add batching for embedding calls to improve throughput and reduce latency/cost.
- Add authentication and rate limiting for production.
- Add unit/integration tests and simple metrics (last synced id, embedding failures).
- Optional: I can add `.env.example`, a CONTRIBUTING section, or a small metrics endpoint.

---

If you'd like, tell me which provider you plan to use and I can add a ready-made `get_embeddings()` snippet for that provider (OpenAI, Hugging Face, or a self-hosted server), plus a `.env.example` file.
- **Additional fields**: Add more columns like `category`, `tags`, `author`, etc.
- **Different ID strategy**: Use UUID instead of auto-increment
- **Multiple source tables**: Join multiple tables in your queries
- **Custom embedding dimensions**: Change `vector(4096)` to match your embedding model

## 🔗 API Endpoints

| Endpoint | Method | Description | Use Case |
|----------|--------|-------------|----------|
| `/healthcheck` | GET | Health status | Monitoring |
| `/documents` | GET | All documents | Data overview |
| `/documents/sync-embeddings` | POST | Sync & embed | Data updates |
| `/search` | POST | Detailed search | Full results |
| `/search-simple` | POST | Simple search | Dify integration |

### 🔍 Search Endpoints Details

#### `/search` - Detailed Search
**Request:**
```json
{
  "query": "government policies",
  "limit": 5,
  "similarity_threshold": 0.7
}
```

**Response:**
```json
{
  "results": [
    {
      "question": "What are the current government policies?",
      "answer": "The government has implemented several policies...",
      "link": "https://example.com/policies",
      "date": "2024-01-10",
      "similarity_score": 0.85
    }
  ],
  "total_results": 1
}
```

#### `/search-simple` - Dify-Optimized Search
**Request:**
```json
{
  "query": "healthcare system",
  "limit": 3,
  "similarity_threshold": 0.8
}
```

**Response:**
```json
{
  "context": "Result 1:\nQuestion: How does the healthcare system work?\nAnswer: The healthcare system operates through...\nSource: https://example.com/healthcare\nDate: 2024-01-10\nRelevance: 0.850\n\nResult 2:\n...",
  "sources": [
    {
      "question": "How does the healthcare system work?",
      "link": "https://example.com/healthcare",
      "date": "2024-01-10",
      "similarity_score": 0.85
    }
  ],
  "total_results": 1
}
```

## 💡 Usage Examples

### Testing with cURL

**Health Check:**
```bash
curl -X GET http://localhost:5000/healthcheck
```

**Search Documents:**
```bash
curl -X POST http://localhost:5000/search-simple \
  -H "Content-Type: application/json" \
  -d '{
    "query": "What is the capital of Malaysia?",
    "limit": 5,
    "similarity_threshold": 0.7
  }'
```

**Sync Embeddings:**
```bash
curl -X POST http://localhost:5000/documents/sync-embeddings \
  -H "Content-Type: application/json"
```

### Testing with Postman

1. **Create new POST request**
2. **Set URL:** `http://localhost:5000/search-simple`
3. **Add header:** `Content-Type: application/json`
4. **Body (raw JSON):**
```json
{
  "query": "your search query here",
  "limit": 5,
  "similarity_threshold": 0.7
}
```

## 🔌 Dify Integration

### Workflow Configuration

**Step 1: Add API Node**
- **URL:** `http://your-server:5000/search-simple`
- **Method:** POST
- **Headers:** `Content-Type: application/json`
- **Body:**
```json
{
  "query": "{{user_query}}",
  "limit": 5,
  "similarity_threshold": 0.7
}
```

**Step 2: Configure LLM Node**
```
Based on the following knowledge base information:
{{api_node.context}}

Please answer the user's question: {{user_query}}

Sources: {{api_node.sources}}
```

### Workflow Flow
```
User Input → API Node (search-simple) → LLM Node → Response
```

## 🔧 Troubleshooting

### Common Issues & Solutions

| Issue | Symptom | Solution |
|-------|---------|----------|
| Connection Error | `MySQL service unavailable` | ✅ Check MySQL server & credentials |
| Embedding Error | `Embedding service unavailable` | ✅ Verify API key & service URL |
| Search Error | `Database search error` | ✅ Check pgvector extension & table |
| No Results | Empty search results | ✅ Lower similarity threshold |
| Docker Build Error | `Build failed` | ✅ Check Dockerfile & dependencies |
| Container Won't Start | `Exit code 1` | ✅ Check environment variables & logs |
| Schema Mismatch | `Column doesn't exist` | ✅ Update table/column names in code |
| Permission Error | `Permission denied` | ✅ Check database user permissions |

### Docker-Specific Troubleshooting

**Container Issues:**
```bash
# Check container logs
docker-compose logs mysql-to-pgvector-embeddings

# Check container status
docker-compose ps

# Restart specific service
docker-compose restart mysql-to-pgvector-embeddings

# Rebuild and restart
docker-compose up --build
```

**Network Issues:**
```bash
# Check if services can communicate
docker-compose exec mysql-to-pgvector-embeddings ping postgres

# Verify port mapping
docker-compose port mysql-to-pgvector-embeddings 5000
```

### Performance Optimization

| Parameter | Recommended Value | Impact |
|-----------|-------------------|---------|
| `similarity_threshold` | 0.5-0.7 | Lower = more results |
| `limit` | 3-10 | Higher = slower response |
| Vector dimensions | 4096 | Match your embedding model |

### Debug Checklist
- [ ] Check server logs for detailed errors
- [ ] Test `/healthcheck` endpoint
- [ ] Verify database connections
- [ ] Test embedding service manually
- [ ] Confirm data exists in both databases
- [ ] **Verify table and column names match your schema**
- [ ] **Check database user has proper permissions**
- [ ] For Docker: Check container logs and network connectivity

## 📊 API Response Codes

| Code | Status | Description |
|------|--------|-------------|
| 200 | ✅ Success | Request completed successfully |
| 422 | ⚠️ Validation Error | Invalid request body |
| 500 | ❌ Server Error | Internal server error |
| 503 | 🔴 Service Unavailable | Database/service down |

## 🔐 Security Best Practices

- 🔒 Use environment variables for sensitive data
- 🛡️ Implement rate limiting in production
- 🔑 Add authentication for protected endpoints
- ✅ Validate all input data
- 🌐 Use HTTPS in production
- 🐳 Don't expose database ports in production Docker setup

## 📝 Technical Notes

### Embedding Model
- **Model:** Qwen/Qwen3-Embedding-8B
- **Dimensions:** 4096
- **Hosting:** Custom deployment (not open source API)

### Docker Architecture
- **Base Image:** Python 3.11-slim
- **Multi-stage builds:** Optimized for production
- **Health checks:** Built-in container health monitoring
- **Volume mounts:** Persistent data storage

### Current Status
- ✅ Core functionality complete
- ✅ Docker deployment ready
- 🔄 Dify integration in progress
- 📊 Performance optimization ongoing

## 🚀 Deployment Options

### Development
```bash
# Local development
python main.py

# Docker development
docker-compose up
```

### Production
```bash
# Production with external databases
docker run -d \
  --name mysql-to-pgvector-embeddings \
  -p 5000:5000 \
  --env-file .env.production \
  --restart unless-stopped \
  mysql-to-pgvector-embeddings

# Or with docker-compose
docker-compose -f docker-compose.prod.yml up -d
```

## 🆘 Support

If you encounter issues:
1. 📖 Check the troubleshooting section
2. 🔍 Review server logs for detailed errors
3. ⚙️ Verify environment variables
4. 🧪 Test individual components
5. 🐳 For Docker issues: Check container logs and network connectivity

---

**Made with ❤️ for dynamic AI knowledge bases**
