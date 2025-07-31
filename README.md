# 🚀 PVRA API: Vectorizing MySQL Data For LLM

A FastAPI-based service that transforms your MySQL database into a powerful vector search engine for AI applications using pgvector and embeddings.

## ‼️Proposed Improvements For This Repository
- Refine chunking method
- Standardize threshold value

## 📋 Table of Contents
- [🎯 Overview](#-overview)
- [🛠️ Installation](#️-installation)
- [🐳 Docker Deployment](#-docker-deployment)
- [⚙️ Configuration](#️-configuration)
- [🔗 API Endpoints](#-api-endpoints)
- [💡 Usage Examples](#-usage-examples)
- [🔌 Dify Integration](#-dify-integration)
- [🔧 Troubleshooting](#-troubleshooting)

## 🎯 Overview

### Problem Statement
Your client's MySQL database contains dynamic content that needs to power a chatbot, but traditional knowledge bases are static and don't sync with live data updates.

### Solution Architecture
```
MySQL Database → PostgreSQL + pgvector → Dify Workflow → AI Chatbot
```

### Key Features
- 🔄 **Real-time sync** between MySQL and PostgreSQL
- 🔍 **Vector similarity search** using embeddings
- 🤖 **Dify integration** through API nodes
- 📊 **Custom embedding model** (Qwen/Qwen3-Embedding-8B)
- 🐳 **Docker support** for easy deployment

## 🛠️ Installation

### Prerequisites
| Component | Version | Purpose |
|-----------|---------|---------|
| Python | 3.8+ | Runtime environment |
| MySQL | Any | Source database |
| PostgreSQL | Latest | Vector database |
| pgvector | Latest | Vector extension |
| Embedding API | Compatible | Text embeddings |
| Docker | Latest | Containerization (optional) |

### Quick Start (Traditional)
1. **Clone and setup:**
```bash
git clone <your-repo>
cd pvra-api
pip install -r requirements.txt
```

2. **Install dependencies:**
```bash
pip install fastapi uvicorn aiomysql psycopg2-binary python-dotenv pydantic requests numpy
```

3. **Run the API:**
```bash
run.bat
# or
python main.py
```

## 🐳 Docker Deployment

### Option 1: Docker Compose (Recommended)
**Complete stack with PostgreSQL + pgvector:**
```bash
# Clone the repository
git clone <your-repo>
cd pvra-api

# Configure environment variables
cp .env.example .env
# Edit .env with your settings

# Start the entire stack
docker-compose up -d

# Check logs
docker-compose logs -f pvra-api
```

### Option 2: Docker Only
**Use existing databases:**
```bash
# Build the image
docker build -t pvra-api .

# Run the container
docker run -d \
  --name pvra-api \
  -p 5000:5000 \
  --env-file .env \
  pvra-api
```

### Docker Services Overview
| Service | Port | Description |
|---------|------|-------------|
| `pvra-api` | 5000 | Main FastAPI application |
| `postgres` | 5432 | PostgreSQL with pgvector |
| `adminer` | 8080 | Database management UI |

### Docker Commands
```bash
# View running containers
docker-compose ps

# Stop services
docker-compose down

# Rebuild after code changes
docker-compose up --build

# View logs
docker-compose logs -f [service-name]

# Execute commands in container
docker-compose exec pvra-api bash
```

## ⚙️ Configuration

### Environment Variables
Create a `.env` file with the following configuration:

```env
# 🗄️ MySQL Configuration
DB_HOST=localhost
DB_PORT=3306
DB_USER=your_mysql_user
DB_PASSWORD=your_mysql_password
DB_NAME=db_ses

# 🐘 PostgreSQL Configuration
PG_HOST=localhost
PG_PORT=5432
PG_USER=your_pg_user
PG_PASSWORD=your_pg_password
PGVECTOR_DB_NAME=your_pgvector_db
PG_DB_NAME=your_pg_db

# 🧠 Embedding Service Configuration
EMBEDDING_MODEL_HOST=https://api.openai.com/v1
EMBEDDING_API_KEY=your_api_key
EMBEDDING_MODEL_NAME=text-embedding-3-large

# ⚙️ Application Configuration
APP_DEBUG=false
```

### Docker Environment Variables
For Docker deployment, update these values:
```env
# When using docker-compose
PG_HOST=postgres
PG_PORT=5432

# External MySQL (update as needed)
DB_HOST=your_mysql_host
```

### Database Schema

> **⚠️ Important Note:** The database schema shown below is specific to this example implementation. You should modify the table names, column names, and data types to match your existing database structure. The code can be easily adapted to work with any MySQL source table and PostgreSQL vector table by updating the SQL queries and column mappings in the FastAPI application.

**MySQL Source Table (`tbl_genie_genie`) - Example Schema:**
```sql
CREATE TABLE tbl_genie_genie (
    id INT PRIMARY KEY AUTO_INCREMENT,
    genie_question TEXT,
    genie_answer TEXT,
    genie_questiondate DATE,
    genie_sourcelink TEXT
);
```

**PostgreSQL Vector Table (`genie_documents`) - Example Schema:**
```sql
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE genie_documents (
    id SERIAL PRIMARY KEY,
    question TEXT UNIQUE,
    answer TEXT,
    link TEXT,
    date DATE,
    question_embedding vector(4096),
    answer_embedding vector(4096)
);

CREATE TABLE migration_tracker (
    id SERIAL PRIMARY KEY,
    id_migrated INTEGER
);
```

### 🔧 Adapting to Your Database Schema

To adapt this API to your specific database schema, you'll need to modify the following in your FastAPI code:

**1. Update Table and Column Names:**
```python
# In get_documents() function - modify this query:
await cursor.execute('''
    SELECT 
        your_question_column,    # Replace with your question column
        your_answer_column,      # Replace with your answer column  
        your_date_column,        # Replace with your date column
        your_link_column         # Replace with your link column
    FROM your_mysql_table        # Replace with your MySQL table name
''')

# In sync_embeddings() function - modify this query:
await mysql_cursor.execute("""
    SELECT id, your_question_column, your_answer_column, your_date_column, your_link_column
    FROM your_mysql_table
    WHERE id > %s
""", (last_migrated_id,))
```

**2. Update PostgreSQL Table Structure:**
```sql
-- Modify the genie_documents table to match your needs:
CREATE TABLE your_vector_table (
    id SERIAL PRIMARY KEY,
    your_question_field TEXT UNIQUE,
    your_answer_field TEXT,
    your_link_field TEXT,
    your_date_field DATE,
    question_embedding vector(4096),  -- Keep this for embeddings
    answer_embedding vector(4096)     -- Keep this for embeddings
);
```

**3. Update Search Queries:**
```python
# In both search endpoints, modify the SELECT queries:
cursor.execute(
    """
    SELECT 
        your_question_field,     # Your question field name
        your_answer_field,       # Your answer field name
        your_link_field,         # Your link field name
        your_date_field,         # Your date field name
        1 - (question_embedding <=> %s::vector) as similarity_score
    FROM your_vector_table       # Your PostgreSQL table name
    WHERE question_embedding IS NOT NULL
        AND 1 - (question_embedding <=> %s::vector) > %s
    ORDER BY similarity_score DESC
    LIMIT %s
    """,
    (query_embedding, query_embedding, request.similarity_threshold, request.limit)
)
```

**4. Common Adaptations:**
- **Different data types**: Adjust `TEXT` to `VARCHAR(n)`, `LONGTEXT`, etc.
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
docker-compose logs pvra-api

# Check container status
docker-compose ps

# Restart specific service
docker-compose restart pvra-api

# Rebuild and restart
docker-compose up --build
```

**Network Issues:**
```bash
# Check if services can communicate
docker-compose exec pvra-api ping postgres

# Verify port mapping
docker-compose port pvra-api 5000
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
  --name pvra-api \
  -p 5000:5000 \
  --env-file .env.production \
  --restart unless-stopped \
  pvra-api

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
