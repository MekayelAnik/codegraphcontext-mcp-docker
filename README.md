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
- [Troubleshooting](#troubleshooting)
- [Resources & Support](#resources--support)

---

## Overview

CodeGraphContext MCP Server transforms your codebase into a queryable knowledge graph powered by Neo4j. It provides AI assistants with deep contextual understanding of code relationships, dependencies, and architecture patterns, integrating seamlessly with VS Code, Cursor, Windsurf, and Claude Desktop.

### Key Features

✨ **Intelligent Code Indexing** - Automatically analyzes and graphs code structure  
🔍 **Relationship Analysis** - Query callers, callees, class hierarchies, and dependencies  
📊 **Live Updates** - Real-time file watching with automatic graph synchronization  
🎯 **Dead Code Detection** - Identify unused functions and quality issues  
📈 **Complexity Analysis** - Calculate cyclomatic complexity and find hotspots  
🔗 **Call Chain Tracing** - Track execution flows across hundreds of files  
🚀 **Multiple Protocols** - HTTP, SSE, and WebSocket support  
🗄️ **Graph Database Powered** - Neo4j backend for lightning-fast queries

### Supported Architectures

| Architecture | Status | Notes |
|:-------------|:------:|:------|
| **x86-64** | ✅ Stable | Intel/AMD processors |
| **ARM64** | ✅ Stable | Raspberry Pi, Apple Silicon |

### Available Tags

| Tag | Stability | Use Case |
|:----|:---------:|:---------|
| `stable` | ⭐⭐⭐ | **Production (recommended)** |
| `latest` | ⭐⭐⭐ | Latest features |
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
    image: mekayelanik/codegraphcontext-mcp:latest
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
  -e PORT=8045 \
  -e NEO4J_URI=bolt://your-neo4j:7687 \
  -e NEO4J_USERNAME=neo4j \
  -e NEO4J_PASSWORD=your-password \
  -e PUID=1000 \
  -e PGID=1000 \
  -e PROTOCOL=SHTTP \
  mekayelanik/codegraphcontext-mcp:latest
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
        "find_code",
        "analyze_code_relationships",
        "watch_directory",
        "find_dead_code",
        "execute_cypher_query",
        "calculate_cyclomatic_complexity"
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
Index code from a local directory.

**Parameters:** `directory` (required), `repository_name` (optional)

**Example:** "Index the code in /home/user/my-project"

---

### 📚 add_package_to_graph
Index a Python package or module.

**Parameters:** `package_name` (required)

**Example:** "Add the requests package to the graph"

---

### 🔍 find_code
Search for functions, classes, or code elements.

**Parameters:** `name` (required), `type` (optional)

**Example:** "Find the calculate_total function"

---

### 🔗 analyze_code_relationships
Analyze relationships between code elements.

**Parameters:** `name` (required), `relationship_type` (optional), `max_depth` (optional)

**Example:** "Show what calls the process_payment function"

---

### 👁️ watch_directory
Monitor directory for changes and auto-update graph.

**Parameters:** `directory` (required), `repository_name` (optional)

**Example:** "Watch /home/user/project for changes"

---

### 🔍 find_dead_code
Identify unused functions and dead code.

**Parameters:** `repository_name` (optional)

**Example:** "Find dead code in my-project"

---

### 💾 execute_cypher_query
Execute custom Cypher queries against Neo4j.

**Parameters:** `query` (required), `parameters` (optional)

**Example:** "Execute: MATCH (f:Function) RETURN f.name LIMIT 10"

---

### 📊 calculate_cyclomatic_complexity
Calculate function complexity.

**Parameters:** `function_name` (required), `file_path` (optional)

**Example:** "Calculate complexity of process_data"

---

### 🎯 find_most_complex_functions
Identify most complex functions.

**Parameters:** `limit` (optional), `repository_name` (optional)

**Example:** "Find the 5 most complex functions"

---

### 📋 list_indexed_repositories
List all indexed repositories.

**Example:** "Show all indexed repositories"

---

### 🗑️ delete_repository
Remove repository from graph.

**Parameters:** `repository_path` (required)

**Example:** "Delete repository at /home/user/old-project"

---

### 📈 visualize_graph_query
Generate visualization data.

**Parameters:** `query` (required), `parameters` (optional)

**Example:** "Visualize: MATCH (n)-[r]->(m) RETURN n, r, m"

---

### 📍 list_watched_paths
List monitored directories.

**Example:** "Show watched directories"

---

### 🛑 unwatch_directory
Stop watching a directory.

**Parameters:** `directory` (required)

**Example:** "Stop watching /home/user/project"

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

## Troubleshooting

### Pre-Flight Checklist

- ✅ Docker 23.0+
- ✅ Neo4j running and accessible
- ✅ Port 8045 available
- ✅ Latest image
- ✅ Correct configuration

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
