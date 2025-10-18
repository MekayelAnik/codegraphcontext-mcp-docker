# CodeGraphContext MCP Server
### Multi-Architecture Docker Image for Distributed Deployment

<div align="left">

<img alt="codegraphcontext-mcp" src="https://img.shields.io/badge/CodeGraph-Context-00D9FF?style=for-the-badge&logo=neo4j&logoColor=white" width="400">

[![Docker Pulls](https://img.shields.io/docker/pulls/mekayelanik/codegraphcontext-mcp.svg?style=flat-square)](https://hub.docker.com/r/mekayelanik/codegraphcontext-mcp)
[![Docker Stars](https://img.shields.io/docker/stars/mekayelanik/codegraphcontext-mcp.svg?style=flat-square)](https://hub.docker.com/r/mekayelanik/codegraphcontext-mcp)
[![Docker Image License](https://img.shields.io/badge/license-GPL-blue.svg?style=flat-square)](https://raw.githubusercontent.com/MekayelAnik/codegraphcontext-mcp-docker/refs/heads/main/LICENSE)

**[Docker Image GitHub Repository](https://github.com/MekayelAnik/codegraphcontext-mcp-docker)** • **[Docker Hub](https://hub.docker.com/r/mekayelanik/codegraphcontext-mcp)** • **[Documentation](https://shashankss1205.github.io/CodeGraphContext/)** • **[Main Project GitHub Repository](https://github.com/Shashankss1205/CodeGraphContext)** • **[PyPI Package](https://pypi.org/project/codegraphcontext/)**

</div>

---

## 📋 Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [MCP Client Setup](#mcp-client-setup)
- [Available Tools](#available-tools)
- [Neo4j Setup](#neo4j-setup)
- [Remote Deployment](#remote-deployment)
- [Troubleshooting](#troubleshooting)
- [Resources & Support](#resources--support)

---

## Overview

CodeGraphContext MCP Server transforms your codebase into a queryable knowledge graph powered by Neo4j. It provides AI assistants with deep contextual understanding of code relationships, dependencies, and architecture patterns, integrating seamlessly with VS Code, Cursor, Windsurf, and Claude Desktop.

### Key Features

✨ **Intelligent Code Indexing** - Automatically analyzes and graphs code structure with background job processing  
🔍 **Relationship Analysis** - Query callers, callees, class hierarchies, and dependencies  
📊 **Live Updates** - Real-time file watching with automatic graph synchronization  
🎯 **Dead Code Detection** - Identify unused functions and quality issues  
📈 **Complexity Analysis** - Calculate cyclomatic complexity and find hotspots  
🔗 **Call Chain Tracing** - Track execution flows across hundreds of files  
🚀 **Multiple Protocols** - HTTP, SSE, and WebSocket support  
🗄️ **Graph Database Powered** - Neo4j backend for lightning-fast queries  
⚡ **Async Processing** - Background jobs for large codebases

### Supported Architectures

| Architecture | Status | Notes |
|:-------------|:------:|:------|
| **x86-64** | ✅ Stable | Intel/AMD processors |
| **ARM64** | ✅ Stable | Raspberry Pi, Apple Silicon |

### Available Tags

| Tag | Stability | Use Case |
|:----|:---------:|:---------|
| `stable` | ⭐⭐⭐ | **Production (recommended)** |
| `latest` | ⭐⭐⭐ | Latest stable features |
| `0.1.x` | ⭐⭐⭐ | Version pinning |
| `beta` | ⚠️ | Testing only |

---

## Quick Start

### Prerequisites

- Docker Engine 23.0+
- Neo4j database (local or hosted)

### Docker Compose (Recommended)

```yaml
services:
  neo4j:
    image: neo4j:latest
    container_name: neo4j
    restart: unless-stopped
    ports:
      - "7474:7474"
      - "7687:7687"
    environment:
      - NEO4J_AUTH=neo4j/your-secure-password
      - NEO4J_PLUGINS=["apoc"]
    volumes:
      - neo4j_data:/data

  codegraphcontext-mcp:
    image: mekayelanik/codegraphcontext-mcp:stable
    container_name: cgc-mcp
    restart: unless-stopped
    ports:
      - "8045:8045"
    environment:
      - PORT=8045
      - NEO4J_URI=bolt://neo4j:7687
      - NEO4J_USERNAME=neo4j
      - NEO4J_PASSWORD=your-secure-password
      - PUID=1000
      - PGID=1000
      - TZ=Asia/Dhaka
      - PROTOCOL=SHTTP
      - CORS=*
    volumes:
      - /path/to/your/projects:/workspace:ro
    depends_on:
      - neo4j

volumes:
  neo4j_data:
```

**Deploy:**

```bash
docker compose up -d
docker compose logs -f cgc-mcp
```

### Docker CLI

```bash
docker run -d \
  --name=cgc-mcp \
  --restart=unless-stopped \
  -p 8045:8045 \
  -v /path/to/your/projects:/workspace:ro \
  -e PORT=8045 \
  -e NEO4J_URI=bolt://your-neo4j:7687 \
  -e NEO4J_USERNAME=neo4j \
  -e NEO4J_PASSWORD=your-password \
  -e PUID=1000 \
  -e PGID=1000 \
  -e PROTOCOL=SHTTP \
  mekayelanik/codegraphcontext-mcp:stable
```

### Access Endpoints

| Protocol | Endpoint | Use Case |
|:---------|:---------|:---------|
| **HTTP** | `http://host-ip:8045/mcp` | **Recommended** |
| **SSE** | `http://host-ip:8045/sse` | Real-time streaming |
| **WebSocket** | `ws://host-ip:8045/message` | Bidirectional |
| **Health** | `http://host-ip:8045/healthz` | Monitoring |

> ⏱️ Allow 30-60 seconds for initialization on ARM devices

---

## Configuration

### Environment Variables

| Variable | Default | Description |
|:---------|:-------:|:------------|
| `PORT` | `8045` | Internal server port |
| `NEO4J_URI` | `bolt://localhost:7687` | Neo4j connection string |
| `NEO4J_USERNAME` | `neo4j` | Database username |
| `NEO4J_PASSWORD` | _(required)_ | Database password |
| `PUID` | `1000` | User ID for permissions |
| `PGID` | `1000` | Group ID for permissions |
| `TZ` | `Asia/Dhaka` | Container timezone |
| `PROTOCOL` | `SHTTP` | Transport protocol (`SHTTP`, `SSE`, `WS`) |
| `CORS` | _(none)_ | Cross-Origin config (`*`, domains, regex) |
| `API_KEY` | _(none)_ | Optional authentication |
| `DEBUG_MODE` | `false` | Enable debug mode |

### Volume Mounting

Mount your project directories to make them accessible to the MCP server:

```yaml
volumes:
  - /home/user/projects:/workspace:ro        # Read-only recommended
  - /var/www/apps:/apps:ro
  - /opt/repositories:/repos:ro
```

Then reference paths as `/workspace/project-name`, `/apps/app-name`, etc.

### Neo4j Configuration Examples

```yaml
# Local Docker
environment:
  - NEO4J_URI=bolt://neo4j:7687
  - NEO4J_USERNAME=neo4j
  - NEO4J_PASSWORD=your-password

# Remote Server
environment:
  - NEO4J_URI=bolt://server.com:7687
  - NEO4J_USERNAME=neo4j
  - NEO4J_PASSWORD=your-password

# Neo4j AuraDB (Cloud)
environment:
  - NEO4J_URI=neo4j+s://xxxxx.databases.neo4j.io
  - NEO4J_USERNAME=neo4j
  - NEO4J_PASSWORD=your-auradb-password
```

### CORS Configuration

```yaml
# Development only
environment:
  - CORS=*

# Production - specific domains
environment:
  - CORS=https://example.com,https://app.example.com

# Mixed domains and IPs
environment:
  - CORS=https://example.com,192.168.1.100:3000
```

> ⚠️ **Security:** Never use `CORS=*` in production

---

## MCP Client Setup

### Transport Compatibility

| Client | HTTP | SSE | WebSocket | Recommended |
|:-------|:----:|:---:|:---------:|:------------|
| **VS Code (Cline/Roo-Cline)** | ✅ | ✅ | ❌ | HTTP |
| **Claude Desktop** | ✅ | ✅ | ⚠️* | HTTP |
| **Cursor** | ✅ | ✅ | ⚠️* | HTTP |
| **Windsurf** | ✅ | ✅ | ⚠️* | HTTP |

> ⚠️ *WebSocket is experimental

### VS Code (Cline/Roo-Cline)

Add to `.vscode/settings.json`:

```json
{
  "mcp.servers": {
    "codegraphcontext": {
      "url": "http://host-ip:8045/mcp",
      "transport": "http",
      "autoApprove": [
        "add_code_to_graph",
        "check_job_status",
        "list_jobs",
        "find_code",
        "analyze_code_relationships",
        "watch_directory",
        "execute_cypher_query",
        "add_package_to_graph",
        "find_dead_code",
        "calculate_cyclomatic_complexity",
        "find_most_complex_functions",
        "list_indexed_repositories",
        "delete_repository",
        "list_watched_paths",
        "unwatch_directory"
      ]
    }
  }
}
```

### Claude Desktop

**Config Locations:**
- **Linux:** `~/.config/Claude/claude_desktop_config.json`
- **macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows:** `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "codegraphcontext": {
      "transport": "http",
      "url": "http://localhost:8045/mcp"
    }
  }
}
```

### Cursor

Add to `~/.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "codegraphcontext": {
      "transport": "http",
      "url": "http://host-ip:8045/mcp"
    }
  }
}
```

### Windsurf (Codeium)

Add to `.codeium/mcp_settings.json`:

```json
{
  "mcpServers": {
    "codegraphcontext": {
      "transport": "http",
      "url": "http://host-ip:8045/mcp"
    }
  }
}
```

### Claude Code

Add to `~/.config/claude-code/mcp_config.json`:

```json
{
  "mcpServers": {
    "codegraphcontext": {
      "transport": "http",
      "url": "http://localhost:8045/mcp"
    }
  }
}
```

Or configure via CLI:

```bash
claude-code config mcp add codegraphcontext \
  --transport http \
  --url http://localhost:8045/mcp
```

### GitHub Copilot CLI

Add to `~/.github-copilot/mcp.json`:

```json
{
  "mcpServers": {
    "codegraphcontext": {
      "transport": "http",
      "url": "http://host-ip:8045/mcp"
    }
  }
}
```

Or use environment variable:

```bash
export GITHUB_COPILOT_MCP_SERVERS='{"codegraphcontext":{"transport":"http","url":"http://localhost:8045/mcp"}}'
```

---

## Available Tools

### 📦 add_code_to_graph
Performs a one-time scan of a local folder to add its code to the graph. Ideal for indexing libraries, dependencies, or projects not being actively modified. Returns a job ID for background processing.

**Parameters:** `directory` (required), `repository_name` (optional)

**Example:** "Index the code in /workspace/my-project"

---

### ⏳ check_job_status
Check the status and progress of a background job.

**Parameters:** `job_id` (required)

**Example:** "Check status of job abc123"

---

### 📋 list_jobs
List all background jobs and their current status.

**Example:** "Show all jobs"

---

### 🔍 find_code
Find relevant code snippets related to a keyword (e.g., function name, class name, or content).

**Parameters:** `name` (required), `type` (optional)

**Example:** "Find the calculate_total function"

---

### 🔗 analyze_code_relationships
Analyze code relationships like 'who calls this function' or 'class hierarchy'. Supported query types include: find_callers, find_callees, find_all_callers, find_all_callees, find_importers, who_modifies, class_hierarchy, overrides, dead_code, call_chain, module_deps, variable_scope, find_complexity, find_functions_by_argument, find_functions_by_decorator.

**Parameters:** `name` (required), `relationship_type` (optional), `max_depth` (optional)

**Example:** "Show what calls the process_payment function"

---

### 👁️ watch_directory
Performs an initial scan of a directory and then continuously monitors it for changes, automatically keeping the graph up-to-date. Ideal for projects under active development. Returns a job ID for the initial scan.

**Parameters:** `directory` (required), `repository_name` (optional)

**Example:** "Watch /workspace/active-project for changes"

---

### 💾 execute_cypher_query
Fallback tool to run a direct, read-only Cypher query against the code graph. Use this for complex questions not covered by other tools. The graph contains nodes representing code structures and relationships between them.

**Schema Overview:**
- **Nodes:** Repository, File, Module, Class, Function
- **Properties:** name, path, cyclomatic_complexity (on Function nodes), code
- **Relationships:** CONTAINS, CALLS, IMPORTS, INHERITS

**Parameters:** `query` (required), `parameters` (optional)

**Example:** "Execute: MATCH (f:Function) RETURN f.name LIMIT 10"

---

### 📚 add_package_to_graph
Add a package to the graph by discovering its location. Supports multiple languages. Returns immediately with a job ID.

**Parameters:** `package_name` (required)

**Example:** "Add the requests package to the graph"

---

### 🔍 find_dead_code
Find potentially unused functions (dead code) across the entire indexed codebase, optionally excluding functions with specific decorators.

**Parameters:** `repository_name` (optional), `exclude_decorators` (optional)

**Example:** "Find dead code in my-project"

---

### 📊 calculate_cyclomatic_complexity
Calculate the cyclomatic complexity of a specific function to measure its complexity.

**Parameters:** `function_name` (required), `file_path` (optional)

**Example:** "Calculate complexity of process_data"

---

### 🎯 find_most_complex_functions
Find the most complex functions in the codebase based on cyclomatic complexity.

**Parameters:** `limit` (optional), `repository_name` (optional)

**Example:** "Find the 5 most complex functions"

---

### 📋 list_indexed_repositories
List all indexed repositories.

**Example:** "Show all indexed repositories"

---

### 🗑️ delete_repository
Delete an indexed repository from the graph.

**Parameters:** `repository_path` (required)

**Example:** "Delete repository at /workspace/old-project"

---

### 📈 visualize_graph_query
Generates a URL to visualize the results of a Cypher query in the Neo4j Browser. The user can open this URL in their web browser to see the graph visualization.

**Parameters:** `query` (required), `parameters` (optional)

**Example:** "Visualize: MATCH (n)-[r]->(m) RETURN n, r, m LIMIT 50"

---

### 📁 list_watched_paths
Lists all directories currently being watched for live file changes.

**Example:** "Show watched directories"

---

### 🛑 unwatch_directory
Stops watching a directory for live file changes.

**Parameters:** `directory` (required)

**Example:** "Stop watching /workspace/project"

---

## Neo4j Setup

### Local Neo4j (Docker)

```yaml
services:
  neo4j:
    image: neo4j:latest
    ports:
      - "7474:7474"
      - "7687:7687"
    environment:
      - NEO4J_AUTH=neo4j/your-password
      - NEO4J_PLUGINS=["apoc"]
      - NEO4J_dbms_memory_heap_max__size=2G
    volumes:
      - neo4j_data:/data
```

**Access:** `http://localhost:7474`

### Neo4j AuraDB (Cloud)

1. Create account at [neo4j.com/cloud/aura](https://neo4j.com/cloud/aura/)
2. Create instance and note credentials
3. Configure container with AuraDB URI

### Neo4j Desktop

1. Download [Neo4j Desktop](https://neo4j.com/download/)
2. Create and start database
3. Use `bolt://localhost:7687` connection

---

## Remote Deployment

### Deployment Considerations

The MCP server can be deployed remotely and accessed via URL from your IDE clients. However, understand these requirements:

**Filesystem Access Required:**
- `add_code_to_graph` and `watch_directory` need direct access to code directories
- Mount your project directories into the container via Docker volumes
- Alternative: Use `add_package_to_graph` for public packages

**Query Operations Work Remotely:**
- All analysis tools (`find_code`, `analyze_code_relationships`, etc.) work perfectly over remote connections
- Once code is indexed in Neo4j, location doesn't matter

### Remote Setup Example

**Server (where code exists):**
```yaml
services:
  codegraphcontext-mcp:
    image: mekayelanik/codegraphcontext-mcp:stable
    ports:
      - "8045:8045"
    volumes:
      - /var/repositories:/repos:ro
      - /home/user/projects:/projects:ro
    environment:
      - NEO4J_URI=bolt://neo4j-server:7687
      - NEO4J_USERNAME=neo4j
      - NEO4J_PASSWORD=password
      - CORS=https://your-domain.com
```

**Client (IDE configuration):**
```json
{
  "mcpServers": {
    "codegraphcontext": {
      "transport": "http",
      "url": "http://your-server-ip:8045/mcp"
    }
  }
}
```

### Security Best Practices

- Use HTTPS reverse proxy (nginx/Caddy) for production
- Configure specific CORS domains, never use `*` in production
- Consider VPN/SSH tunneling for sensitive codebases
- Enable `API_KEY` authentication for additional security
- Use read-only volume mounts (`:ro`) when possible

---

## Troubleshooting

### Pre-Flight Checklist

- ✅ Docker 23.0+
- ✅ Neo4j running and accessible
- ✅ Port 8045 available
- ✅ Latest stable image
- ✅ Correct configuration
- ✅ Project directories mounted

### Common Issues

**Container Won't Start**
```bash
docker logs cgc-mcp
docker pull mekayelanik/codegraphcontext-mcp:stable
```

**Neo4j Connection Failed**
```bash
# Test connectivity
docker exec cgc-mcp python3 -c "
from neo4j import GraphDatabase
driver = GraphDatabase.driver('bolt://neo4j:7687', auth=('neo4j', 'password'))
driver.verify_connectivity()
"
```

**Permission Errors**
```bash
id $USER  # Get your UID/GID
# Update PUID and PGID in config
```

**Cannot Access Mounted Directories**
```bash
# Verify mount inside container
docker exec cgc-mcp ls -la /workspace

# Check permissions
docker exec cgc-mcp stat /workspace/your-project
```

**Client Cannot Connect**
```bash
curl http://localhost:8045/healthz
curl http://localhost:8045/mcp
```

**CORS Errors**
```yaml
# Development
environment:
  - CORS=*

# Production
environment:
  - CORS=https://yourdomain.com
```

**Job Processing Issues**
```bash
# Check job status via tool
# "List all jobs" or "Check status of job <job_id>"

# View logs
docker logs cgc-mcp --tail 100 -f
```

---

## Resources & Support

### Documentation
- 📚 [PyPI Package](https://pypi.org/project/codegraphcontext/)
- 📦 [GitHub Repository](https://github.com/Shashankss1205/CodeGraphContext)
- 📖 [Full Documentation](https://shashankss1205.github.io/CodeGraphContext/)
- 🎥 [Demo Video](https://youtu.be/KYYSdxhg1xU)
- 💬 [Discord Community](https://discord.gg/dR4QY32uYQ)

### Neo4j Resources
- 📘 [Neo4j Documentation](https://neo4j.com/docs/)
- 🎓 [GraphAcademy](https://graphacademy.neo4j.com/)
- 📊 [Cypher Language](https://neo4j.com/docs/cypher-manual/)

### Getting Help

**Docker Image Issues:**
- [GitHub Issues](https://github.com/MekayelAnik/codegraphcontext-mcp/issues)
- [Discussions](https://github.com/MekayelAnik/codegraphcontext-mcp/discussions)

**Package Issues:**
- [CodeGraphContext Issues](https://github.com/Shashankss1205/CodeGraphContext/issues)
- [Discord](https://discord.gg/dR4QY32uYQ)

### Updating

```bash
# Docker Compose
docker compose pull
docker compose up -d

# Docker CLI
docker pull mekayelanik/codegraphcontext-mcp:stable
docker stop cgc-mcp && docker rm cgc-mcp
# Run your docker run command again
```

---

## License

Docker Image GPL License - See [LICENSE](https://raw.githubusercontent.com/MekayelAnik/codegraphcontext-mcp-docker/refs/heads/main/LICENSE)

Main Project MIT License - See [LICENSE](https://raw.githubusercontent.com/Shashankss1205/CodeGraphContext/refs/heads/main/LICENSE)

**Disclaimer:** Unofficial Docker image for [CodeGraphContext](https://github.com/Shashankss1205/CodeGraphContext). Not affiliated with Neo4j or Anthropic. Users are responsible for proper Neo4j licensing, security, and compliance.

**Privacy:** This Docker image does not collect, store, or transmit your code or personal data. All data resides on Neo4j instance of your choice.