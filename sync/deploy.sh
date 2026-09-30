#!/usr/bin/env bash
# Deploy del sync nocturno (solo AWS CLI). Idempotente: crea o actualiza.
#   - SSM SecureString con la clave secreta de Supabase (se crea desde ~/.claude/mono-supabase.env si no existe)
#   - Role de la Lambda: logs + invocar la data-Lambda del conector + leer ese parámetro
#   - Lambda proyecciones-sync (Node 22, fuera de la VPC para llegar a Supabase)
#   - Schedule de EventBridge Scheduler: todos los días 03:00 hora Argentina
# Uso (Git Bash, con `aws sso login --profile seeds` hecho):
#   cd sync && MSYS_NO_PATHCONV=1 AWS_PROFILE=seeds bash deploy.sh
set -euo pipefail

REGION="${REGION:-us-east-1}"
FUNCTION_NAME="proyecciones-sync"
ROLE_NAME="proyecciones-sync-role"
SCHED_ROLE_NAME="proyecciones-sync-scheduler-role"
SCHEDULE_NAME="proyecciones-sync-nightly"
KEY_PARAM="/proyecciones-sync/supabase-key"
DATA_FUNCTION="seeds-docs-mcp-data"
SUPABASE_URL="https://xrqxikvhhkkxitsbqxkv.supabase.co"
ENV_FILE="${ENV_FILE:-$HOME/.claude/mono-supabase.env}"
export AWS_REGION="$REGION"

cd "$(dirname "$0")"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
echo ">> Cuenta ${ACCOUNT_ID}  Region ${REGION}"

# --- Clave de Supabase en SSM ---
if ! aws ssm get-parameter --name "$KEY_PARAM" >/dev/null 2>&1; then
  KEY="$(grep -E '^SUPABASE_SERVICE_ROLE_KEY=' "$ENV_FILE" | cut -d= -f2- | tr -d '\r')"
  [ -n "$KEY" ] && [ "$KEY" != "PEGAR_ACA" ] || { echo "Falta la clave en ${ENV_FILE}"; exit 1; }
  echo ">> Creando parámetro SSM ${KEY_PARAM} ..."
  aws ssm put-parameter --name "$KEY_PARAM" --type SecureString --value "$KEY" >/dev/null
fi

# --- Role de la Lambda ---
if ! aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  echo ">> Creando role ${ROLE_NAME} ..."
  aws iam create-role --role-name "$ROLE_NAME" --assume-role-policy-document \
    '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}' >/dev/null
  aws iam attach-role-policy --role-name "$ROLE_NAME" \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
  sleep 10 # el role tarda en propagarse
fi
aws iam put-role-policy --role-name "$ROLE_NAME" --policy-name proyecciones-sync-access --policy-document \
  '{"Version":"2012-10-17","Statement":[
    {"Effect":"Allow","Action":"lambda:InvokeFunction","Resource":"arn:aws:lambda:'"${REGION}"':'"${ACCOUNT_ID}"':function:'"${DATA_FUNCTION}"'"},
    {"Effect":"Allow","Action":"ssm:GetParameter","Resource":"arn:aws:ssm:'"${REGION}"':'"${ACCOUNT_ID}"':parameter'"${KEY_PARAM}"'"},
    {"Effect":"Allow","Action":"kms:Decrypt","Resource":"*","Condition":{"StringEquals":{"kms:ViaService":"ssm.'"${REGION}"'.amazonaws.com"}}}]}'
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

# --- Código (el SDK de AWS ya viene en el runtime de Node 22: solo se empaqueta src/) ---
echo ">> Empaquetando function.zip ..."
rm -f function.zip
/c/Windows/System32/tar.exe -a -c -f function.zip -C src handler.mjs payload.mjs

ENV_VARS="Variables={DATA_FUNCTION=${DATA_FUNCTION},SUPABASE_URL=${SUPABASE_URL},KEY_PARAM=${KEY_PARAM}}"
if aws lambda get-function --function-name "$FUNCTION_NAME" >/dev/null 2>&1; then
  echo ">> Actualizando ${FUNCTION_NAME} ..."
  aws lambda update-function-code --function-name "$FUNCTION_NAME" --zip-file fileb://function.zip >/dev/null
  aws lambda wait function-updated --function-name "$FUNCTION_NAME"
  aws lambda update-function-configuration --function-name "$FUNCTION_NAME" --role "$ROLE_ARN" \
    --runtime nodejs22.x --handler handler.handler --timeout 120 --memory-size 256 --environment "$ENV_VARS" >/dev/null
else
  echo ">> Creando ${FUNCTION_NAME} ..."
  aws lambda create-function --function-name "$FUNCTION_NAME" --role "$ROLE_ARN" \
    --runtime nodejs22.x --handler handler.handler --timeout 120 --memory-size 256 \
    --environment "$ENV_VARS" --zip-file fileb://function.zip >/dev/null
fi
aws lambda wait function-updated --function-name "$FUNCTION_NAME"
FUNCTION_ARN="arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:${FUNCTION_NAME}"

# --- Schedule nocturno ---
if ! aws iam get-role --role-name "$SCHED_ROLE_NAME" >/dev/null 2>&1; then
  echo ">> Creando role ${SCHED_ROLE_NAME} ..."
  aws iam create-role --role-name "$SCHED_ROLE_NAME" --assume-role-policy-document \
    '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"scheduler.amazonaws.com"},"Action":"sts:AssumeRole"}]}' >/dev/null
  sleep 10
fi
aws iam put-role-policy --role-name "$SCHED_ROLE_NAME" --policy-name invoke-proyecciones-sync --policy-document \
  '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":"lambda:InvokeFunction","Resource":"'"${FUNCTION_ARN}"'"}]}'

SCHED_ARGS=(--name "$SCHEDULE_NAME" --schedule-expression "cron(0 3 * * ? *)"
  --schedule-expression-timezone "America/Argentina/Buenos_Aires" --flexible-time-window Mode=OFF
  --target "Arn=${FUNCTION_ARN},RoleArn=arn:aws:iam::${ACCOUNT_ID}:role/${SCHED_ROLE_NAME}")
if aws scheduler get-schedule --name "$SCHEDULE_NAME" >/dev/null 2>&1; then
  aws scheduler update-schedule "${SCHED_ARGS[@]}" >/dev/null
else
  aws scheduler create-schedule "${SCHED_ARGS[@]}" >/dev/null
fi
rm -f function.zip

echo ">> Listo. Corre todos los días a las 03:00 (hora Argentina)."
echo ">> Para correrlo ahora:  aws lambda invoke --function-name ${FUNCTION_NAME} out.json && cat out.json"
