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
Environment="$3"

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

# ---------------------------------------------------------------------------
# Parámetros inyectados por el pipeline (workflow deploy.yml)
# ---------------------------------------------------------------------------
Parameters:
  Environment:
    Type: String
    AllowedValues: [dev, staging, prod]
    Description: Ambiente destino. Se usa también como nombre de alias.
 
  RedisHostParam:
    Type: String
    Value: !Ref Environment-redis-host  # Ejemplo: "dev-redis-host"
    Description: Ruta SSM que contiene redis_host para este ambiente.
 
  DbHostParam:
    Type: String
    Value: !Ref Environment-db-host  # Ejemplo: "dev-db-host"
    Description: Ruta SSM que contiene db_host para este ambiente.

# ---------------------------------------------------------------------------
# Config de despliegue gradual por ambiente:
#   - dev/staging: AllAtOnce (rápido, bajo riesgo)
#   - prod:        Canary 10% por 5 min (detecta fallas antes del 100%)
# ---------------------------------------------------------------------------
Mappings:
  DeployConfig:
    dev:
      Type: AllAtOnce
    staging:
      Type: AllAtOnce
    prod:
      Type: Canary10Percent5Minutes

Globals:
  Function:
    Timeout: 30
    MemorySize: 128
    RunTime: python3.13
    architectures:
      - arm64

Resources:
  ${LAMBDA_NAME//[-_]/}Function:
    Type: AWS::Serverless::Function
    Properties:
      FunctionName: ${LAMBDA_NAME}-${Environment}
      CodeUri: ./
      Handler: lambda_function.lambda_handler
      Environment:
        Variables:
          ENVIRONMENT: !Ref Environment
          REDIS_HOST: !Ref RedisHostParam
          DB_HOST: !Ref DbHostParam
      # --- Clave del rollback optimizado ---
      AutoPublishAlias: !Ref Environment      # crea/actualiza alias = nombre del ambiente
      DeploymentPreference:
        Type: !FindInMap [DeployConfig, !Ref Environment, Type]
        Alarms:
          # Si estas alarmas se disparan durante el shift de tráfico,
          # CodeDeploy revierte automáticamente al alias anterior.
          - !Ref ErrorsAlarm
    # Alarma sobre errores de la función (versión nueva durante el shift)
  ErrorsAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmDescription: !Sub "Errores en ${LAMBDA_NAME}-${Environment}"
      Namespace: AWS/Lambda
      MetricName: Errors
      Dimensions:
        - Name: FunctionName
          Value: !Ref ${LAMBDA_NAME}Function
        - Name: Resource
          Value: !Sub "${LAMBDA_NAME}Function:${Environment}"
      Statistic: Sum
      Period: 60
      EvaluationPeriods: 1
      Threshold: 1
      ComparisonOperator: GreaterThanOrEqualToThreshold
      TreatMissingData: notBreaching
 
Outputs:
  FunctionArn:
    Value: !GetAtt ${LAMBDA_NAME}Function.Arn
  AliasArn:
    Value: !Ref ${LAMBDA_NAME}Function.Alias
YAMLEOF

echo "✓ Lambda '${LAMBDA_NAME}' creada en: ${TARGET}"
echo ""
echo "Estructura:"
echo "  ${TARGET}/"
echo "    ├── lambda_function.py"
echo "    └── template.yaml"