#!/bin/bash
set -e
/usr/local/bin/banner.sh

# Default values
readonly DEFAULT_PUID=1000
readonly DEFAULT_PGID=1000
readonly DEFAULT_PORT=8045
readonly DEFAULT_PROTOCOL="SHTTP"
readonly SAFE_API_KEY_REGEX='^[A-Za-z0-9_:.@+= -]{5,128}$'
readonly FIRST_RUN_FILE="/tmp/first_run_complete"

# Neo4j defaults
readonly DEFAULT_NEO4J_URI="bolt://localhost:7687"
readonly DEFAULT_NEO4J_USERNAME="neo4j"
readonly DEFAULT_NEO4J_PASSWORD=""

# Function to trim whitespace using parameter expansion
trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}

# Validate positive integers
is_positive_int() {
    [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -gt 0 ]
}

# First run handling
handle_first_run() {
    local uid_gid_changed=0

    # Handle PUID/PGID logic
    if [[ -z "$PUID" && -z "$PGID" ]]; then
        PUID="$DEFAULT_PUID"
        PGID="$DEFAULT_PGID"
        echo "PUID and PGID not set. Using defaults: PUID=$PUID, PGID=$PGID"
    elif [[ -n "$PUID" && -z "$PGID" ]]; then
        if is_positive_int "$PUID"; then
            PGID="$PUID"
        else
            echo "Invalid PUID: '$PUID'. Using default: $DEFAULT_PUID"
            PUID="$DEFAULT_PUID"
            PGID="$DEFAULT_PGID"
        fi
    elif [[ -z "$PUID" && -n "$PGID" ]]; then
        if is_positive_int "$PGID"; then
            PUID="$PGID"
        else
            echo "Invalid PGID: '$PGID'. Using default: $DEFAULT_PGID"
            PUID="$DEFAULT_PUID"
            PGID="$DEFAULT_PGID"
        fi
    else
        if ! is_positive_int "$PUID"; then
            echo "Invalid PUID: '$PUID'. Using default: $DEFAULT_PUID"
            PUID="$DEFAULT_PUID"
        fi
        
        if ! is_positive_int "$PGID"; then
            echo "Invalid PGID: '$PGID'. Using default: $DEFAULT_PGID"
            PGID="$DEFAULT_PGID"
        fi
    fi

    # Check existing UID/GID conflicts
    local current_user current_group
    current_user=$(id -un "$PUID" 2>/dev/null || true)
    current_group=$(getent group "$PGID" | cut -d: -f1 2>/dev/null || true)

    [[ -n "$current_user" && "$current_user" != "node" ]] &&
        echo "Warning: UID $PUID already in use by $current_user - may cause permission issues"

    [[ -n "$current_group" && "$current_group" != "node" ]] &&
        echo "Warning: GID $PGID already in use by $current_group - may cause permission issues"

    # Modify UID/GID if needed
    if [ "$(id -u node)" -ne "$PUID" ]; then
        if usermod -o -u "$PUID" node 2>/dev/null; then
            uid_gid_changed=1
        else
            echo "Error: Failed to change UID to $PUID. Using existing UID $(id -u node)"
            PUID=$(id -u node)
        fi
    fi

    if [ "$(id -g node)" -ne "$PGID" ]; then
        if groupmod -o -g "$PGID" node 2>/dev/null; then
            uid_gid_changed=1
        else
            echo "Error: Failed to change GID to $PGID. Using existing GID $(id -g node)"
            PGID=$(id -g node)
        fi
    fi

    [ "$uid_gid_changed" -eq 1 ] && echo "Updated UID/GID to PUID=$PUID, PGID=$PGID"
    touch "$FIRST_RUN_FILE"
}

# Validate and set PORT
validate_port() {
    PORT=${PORT:-$DEFAULT_PORT}
    
    if ! is_positive_int "$PORT"; then
        echo "Invalid PORT: '$PORT'. Using default: $DEFAULT_PORT"
        PORT="$DEFAULT_PORT"
    elif [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
        echo "Invalid PORT: '$PORT'. Using default: $DEFAULT_PORT"
        PORT="$DEFAULT_PORT"
    fi
    
    if [ "$PORT" -lt 1024 ] && [ "$(id -u)" -ne 0 ]; then
        echo "Warning: Port $PORT is privileged and might require root"
    fi
}

# Validate and set API_KEY (optional for CodeGraphContext)
validate_api_key() {
    if [[ -n "$API_KEY" ]]; then
        if [[ "$API_KEY" =~ $SAFE_API_KEY_REGEX ]]; then
            [[ "$API_KEY" =~ ^(password|secret|admin|token|key|test|demo)$ ]] &&
                echo "Warning: API_KEY is using a common value - consider more complex key"
        else
            echo "Invalid API_KEY. Must be 5-128 chars with safe symbols. Ignoring API_KEY."
            API_KEY=""
        fi
    fi
}

# Validate Neo4j configuration
validate_neo4j_config() {
    NEO4J_URI=${NEO4J_URI:-$DEFAULT_NEO4J_URI}
    NEO4J_USERNAME=${NEO4J_USERNAME:-$DEFAULT_NEO4J_USERNAME}
    NEO4J_PASSWORD=${NEO4J_PASSWORD:-$DEFAULT_NEO4J_PASSWORD}

    # Validate URI format
    if [[ ! "$NEO4J_URI" =~ ^(bolt|neo4j|bolt\+s|neo4j\+s|bolt\+ssc|neo4j\+ssc)://.*$ ]]; then
        echo "Warning: Invalid NEO4J_URI format. Using default: $DEFAULT_NEO4J_URI"
        NEO4J_URI="$DEFAULT_NEO4J_URI"
    fi

    # Check if Neo4j credentials are provided
    if [[ -z "$NEO4J_PASSWORD" ]]; then
        echo "WARNING: NEO4J_PASSWORD not set. CodeGraphContext requires Neo4j database connection."
        echo "Please provide NEO4J_URI, NEO4J_USERNAME, and NEO4J_PASSWORD environment variables."
    fi

    # Export Neo4j environment variables for cgc
    export NEO4J_URI
    export NEO4J_USERNAME
    export NEO4J_PASSWORD
}

# Validate CORS patterns
validate_cors() {
    CORS_ARGS=()
    ALLOW_ALL_CORS=false
    local cors_value

    if [[ -n "${CORS}" ]]; then
        IFS=',' read -ra CORS_VALUES <<< "$CORS"
        for cors_value in "${CORS_VALUES[@]}"; do
            cors_value=$(trim "$cors_value")
            [[ -z "$cors_value" ]] && continue

            if [[ "$cors_value" =~ ^(all|\*)$ ]]; then
                ALLOW_ALL_CORS=true
                CORS_ARGS=(--cors)
                echo "Caution! CORS allowing all origins - security risk in production!"
                break
            elif [[ "$cors_value" =~ ^/.*/$ ]] ||
                 [[ "$cors_value" =~ ^https?:// ]] ||
                 [[ "$cors_value" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(:[0-9]+)?$ ]] ||
                 [[ "$cors_value" =~ ^https?://[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(:[0-9]+)?$ ]] ||
                 [[ "$cors_value" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(:[0-9]+)?$ ]]
            then
                CORS_ARGS+=(--cors "$cors_value")
            else
                echo "Warning: Invalid CORS pattern '$cors_value' - skipping"
            fi
        done
    fi
}

# Main execution
main() {
    # Trim all input parameters
    [[ -n "${PUID:-}" ]] && PUID=$(trim "$PUID")
    [[ -n "${PGID:-}" ]] && PGID=$(trim "$PGID")
    [[ -n "${PORT:-}" ]] && PORT=$(trim "$PORT")
    [[ -n "${API_KEY:-}" ]] && API_KEY=$(trim "$API_KEY")
    [[ -n "${PROTOCOL:-}" ]] && PROTOCOL=$(trim "$PROTOCOL")
    [[ -n "${CORS:-}" ]] && CORS=$(trim "$CORS")
    [[ -n "${NEO4J_URI:-}" ]] && NEO4J_URI=$(trim "$NEO4J_URI")
    [[ -n "${NEO4J_USERNAME:-}" ]] && NEO4J_USERNAME=$(trim "$NEO4J_USERNAME")
    [[ -n "${NEO4J_PASSWORD:-}" ]] && NEO4J_PASSWORD=$(trim "$NEO4J_PASSWORD")

    # First run handling
    if [[ ! -f "$FIRST_RUN_FILE" ]]; then
        handle_first_run
    fi

    # Validate configurations
    validate_port
    validate_api_key
    validate_neo4j_config
    validate_cors

    # Build MCP server command - cgc start for CodeGraphContext
    MCP_SERVER_CMD="cgc start"

    # Protocol selection
    local PROTOCOL_UPPER=${PROTOCOL:-$DEFAULT_PROTOCOL}
    PROTOCOL_UPPER=${PROTOCOL_UPPER^^}

    case "$PROTOCOL_UPPER" in
        "SHTTP"|"STREAMABLEHTTP")
            CMD_ARGS=(npx --yes supergateway --port "$PORT" --streamableHttpPath /mcp --outputTransport streamableHttp "${CORS_ARGS[@]}" --healthEndpoint /healthz --stdio "$MCP_SERVER_CMD")
            PROTOCOL_DISPLAY="SHTTP/streamableHttp"
            ;;
        "SSE")
            CMD_ARGS=(npx --yes supergateway --port "$PORT" --ssePath /sse --outputTransport sse "${CORS_ARGS[@]}" --healthEndpoint /healthz --stdio "$MCP_SERVER_CMD")
            PROTOCOL_DISPLAY="SSE/Server-Sent Events"
            ;;
        "WS"|"WEBSOCKET")
            CMD_ARGS=(npx --yes supergateway --port "$PORT" --messagePath /message --outputTransport ws "${CORS_ARGS[@]}" --healthEndpoint /healthz --stdio "$MCP_SERVER_CMD")
            PROTOCOL_DISPLAY="WS/WebSocket"
            ;;
        *)
            echo "Invalid PROTOCOL: '$PROTOCOL'. Using default: $DEFAULT_PROTOCOL"
            CMD_ARGS=(npx --yes supergateway --port "$PORT" --streamableHttpPath /mcp --outputTransport streamableHttp "${CORS_ARGS[@]}" --healthEndpoint /healthz --stdio "$MCP_SERVER_CMD")
            PROTOCOL_DISPLAY="SHTTP/streamableHttp"
            ;;
    esac

    # Debug mode handling
    case "${DEBUG_MODE:-}" in
        [1YyTt]*|[Oo][Nn]|[Yy][Ee][Ss]|[Ee][Nn][Aa][Bb][Ll][Ee]*)
            echo "DEBUG MODE: Installing nano and pausing container"
            apk add --no-cache nano 2>/dev/null || echo "Warning: Failed to install nano"
            echo "Container paused for debugging. Exec into container to investigate."
            exec tail -f /dev/null
            ;;
        *)
            # Normal execution
            echo "Launching CodeGraphContext MCP Server with protocol: $PROTOCOL_DISPLAY on port: $PORT"
            echo "Neo4j Connection: $NEO4J_URI (user: $NEO4J_USERNAME)"
            
            # Display authentication status
            if [[ -n "$API_KEY" ]]; then
                echo "API_KEY authentication is ENABLED for the gateway"
            else
                echo "Note: API_KEY authentication is DISABLED for the gateway"
            fi
            
            # Check for required commands
            if ! command -v cgc &>/dev/null; then
                echo "Error: cgc command not available. CodeGraphContext may not be properly installed."
                exit 1
            fi

            if ! command -v npx &>/dev/null; then
                echo "Error: npx not available. Cannot start supergateway."
                exit 1
            fi

            # Verify Neo4j connection before starting (optional but recommended)
            if command -v python3 &>/dev/null && [[ -n "$NEO4J_PASSWORD" ]]; then
                echo "Verifying Neo4j connection..."
                python3 -c "
from neo4j import GraphDatabase
import sys
import os
try:
    driver = GraphDatabase.driver(
        os.environ['NEO4J_URI'],
        auth=(os.environ['NEO4J_USERNAME'], os.environ['NEO4J_PASSWORD'])
    )
    driver.verify_connectivity()
    driver.close()
    print('Neo4j connection verified successfully')
except Exception as e:
    print(f'Warning: Neo4j connection check failed: {e}', file=sys.stderr)
    print('Continuing anyway - cgc will handle connection errors', file=sys.stderr)
" || echo "Neo4j verification skipped or failed - continuing anyway"
            fi

            if [ "$(id -u)" -eq 0 ]; then
                exec su-exec node "${CMD_ARGS[@]}"
            else
                if [ "$PORT" -lt 1024 ]; then
                    echo "Error: Cannot bind to privileged port $PORT without root"
                    exit 1
                fi
                exec "${CMD_ARGS[@]}"
            fi
            ;;
    esac
}

# Run the script with error handling
if main "$@"; then
    exit 0
else
    exit 1
fi