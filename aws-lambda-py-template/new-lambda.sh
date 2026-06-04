#!/usr/bin/env bash
#
# new-lambda.sh — Generador de templates de AWS Lambda
#
# Crea una estructura estándar para una nueva función Lambda:
#   <lambda_name>/
#     ├── lambda_function.py   (handler con boilerplate)
#     └── template.yaml        (SAM template: Python 3.13, arm64)
#
# Uso:
#   ./new-lambda.sh <lambda_name> [directorio_destino]
#
# Ejemplo:
#   ./new-lambda.sh procesar-pagos
#   ./new-lambda.sh procesar-pagos ./funciones
#
set -euo pipefail

RUNTIME="python3.13"
ARCH="arm64"

# ----- Validación de argumentos -------------------------------------------
if [[ $# -lt 1 ]]; then
  echo "Uso: $0 <lambda_name> [directorio_destino]" >&2
  exit 1
fi

LAMBDA_NAME="$1"
DEST_DIR="${2:-.}"

# Nombre válido: letras, números, guion y guion bajo
if [[ ! "$LAMBDA_NAME" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
  echo "Error: '$LAMBDA_NAME' no es un nombre válido (usa letras, números, '-' o '_')." >&2
  exit 1
fi

TARGET="${DEST_DIR%/}/${LAMBDA_NAME}"

if [[ -e "$TARGET" ]]; then
  echo "Error: '$TARGET' ya existe. Aborta para no sobrescribir." >&2
  exit 1
fi

# ----- Verificar runtime disponible en SAM (si SAM CLI está instalado) ----
if command -v sam >/dev/null 2>&1; then
  SAM_VERSION="$(sam --version 2>/dev/null | awk '{print $NF}')"
  echo "→ AWS SAM CLI detectado (v${SAM_VERSION}). Runtime objetivo: ${RUNTIME}"
else
  echo "→ Aviso: SAM CLI no está instalado. Se genera el template igual;" \
       "valida con 'sam validate' cuando lo tengas."
fi

# ----- Crear estructura -----------------------------------------------------
mkdir -p "$TARGET"

# lambda_function.py
cat > "${TARGET}/lambda_function.py" <<'PYEOF'
import json


def lambda_handler(event, context):
    # TODO implement
    return {
        'statusCode': 200,
        'body': json.dumps('Hello from Lambda!')
    }
PYEOF

# template.yaml (SAM)
cat > "${TARGET}/template.yaml" <<YAMLEOF
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31
Description: >
  ${LAMBDA_NAME} — generada automáticamente.

Globals:
  Function:
    Timeout: 30
    MemorySize: 128

Resources:
  ${LAMBDA_NAME//[-_]/}Function:
    Type: AWS::Serverless::Function
    Properties:
      FunctionName: ${LAMBDA_NAME}
      CodeUri: ./
      Handler: lambda_function.lambda_handler
      Runtime: ${RUNTIME}
      Architectures:
        - ${ARCH}
YAMLEOF

echo "✓ Lambda '${LAMBDA_NAME}' creada en: ${TARGET}"
echo ""
echo "Estructura:"
echo "  ${TARGET}/"
echo "    ├── lambda_function.py"
echo "    └── template.yaml"