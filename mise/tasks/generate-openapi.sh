#!/bin/bash
#MISE description="Generates the Swift client code from the OpenAPI specification."

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
SOURCES_DIR="$ROOT_DIR/Sources/TuistSDK"

mise x spm:apple/swift-openapi-generator@1.10.3 -- swift-openapi-generator generate \
    --mode types \
    --mode client \
    --output-directory "$SOURCES_DIR" \
    --config "$SOURCES_DIR/openapi-generator-config.yaml" \
    "$SOURCES_DIR/openapi.yml"
