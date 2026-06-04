# new-lambda.sh — Generador de templates de AWS Lambda

## ¿De qué trata?

`new-lambda.sh` es un script de automatización que genera, en segundos, la
estructura base de una nueva función AWS Lambda lista para desplegarse con
AWS SAM. Su objetivo es **estandarizar la creación de funciones y reducir el
tiempo de atención al equipo**: en lugar de copiar/pegar boilerplate (y arrastrar
errores de tipeo en el handler), cualquier integrante ejecuta un comando y obtiene
una función consistente, con runtime y arquitectura ya fijados por convención.

Cada función generada incluye:

- Un handler de Python con el boilerplate mínimo funcional.
- Un `template.yaml` de SAM preconfigurado con **Python 3.13** y arquitectura **arm64**.
- Validaciones que evitan nombres inválidos y la sobreescritura accidental de carpetas.

---

## Estructura generada

Al ejecutar el script con un nombre de función (por ejemplo `procesar-pagos`),
se crea:

```
procesar-pagos/
├── lambda_function.py   # Handler con boilerplate
└── template.yaml        # SAM template (Python 3.13, arm64)
```

### Contenido de `lambda_function.py`

```python
import json


def lambda_handler(event, context):
    # TODO implement
    return {
        'statusCode': 200,
        'body': json.dumps('Hello from Lambda!')
    }
```

### Contenido de `template.yaml`

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31
Description: >
  procesar-pagos — generada automáticamente.

Globals:
  Function:
    Timeout: 30
    MemorySize: 128

Resources:
  procesarpagosFunction:
    Type: AWS::Serverless::Function
    Properties:
      FunctionName: procesar-pagos
      CodeUri: ./
      Handler: lambda_function.lambda_handler
      Runtime: python3.13
      Architectures:
        - arm64
```

> **Nota sobre el nombre del handler:** el campo `Handler` sigue el formato
> `archivo.funcion`, por lo que **debe** ser `lambda_function.lambda_handler`.
> AWS importa ese módulo y busca esa función por nombre exacto; cualquier
> discrepancia produce un `Runtime.ImportModuleError` en la invocación.

---

## Recursos necesarios

### Para generar la función (mínimo)

| Recurso          | Requisito                                  |
| ---------------- | ------------------------------------------ |
| Bash             | 4.0 o superior (Linux / macOS / WSL)       |
| Permisos         | Escritura en el directorio destino         |

El script funciona sin SAM CLI instalado: detecta su ausencia y avisa, pero
genera los archivos igual.

### Para validar y desplegar la función

| Recurso              | Requisito                                                        |
| -------------------- | ---------------------------------------------------------------- |
| AWS SAM CLI          | **≥ 1.131** (necesaria para Python 3.13 en `sam validate --lint`) |
| Python               | 3.13 (para pruebas locales con `sam local`)                      |
| Docker               | Requerido por `sam local invoke` / `sam build --use-container`   |
| AWS CLI + credenciales | Configuradas (`aws configure`) para `sam deploy`               |

> **Versión de SAM CLI:** las versiones 1.128–1.130 reconocían `python3.13` al
> desplegar pero fallaban en `sam validate --lint` con un falso positivo. Fija
> `>= 1.131` en el entorno del equipo o en el pipeline de CI.

---

## Modo de ejecución

### 1. Dar permisos de ejecución (solo la primera vez)

```bash
chmod +x new-lambda.sh
```

### 2. Ejecutar

```bash
./new-lambda.sh <lambda_name> [directorio_destino]
```

| Parámetro            | Obligatorio | Descripción                                                       |
| -------------------- | ----------- | ----------------------------------------------------------------- |
| `lambda_name`        | Sí          | Nombre de la función. Debe iniciar con letra; permite `a-z A-Z 0-9 - _`. |
| `directorio_destino` | No          | Carpeta donde crear la función. Por defecto: directorio actual.   |

### Ejemplos

```bash
# Crear en el directorio actual
./new-lambda.sh procesar-pagos

# Crear dentro de una subcarpeta
./new-lambda.sh procesar-pagos ./funciones
```

### 3. Validar y desplegar (flujo SAM típico)

```bash
cd procesar-pagos
sam validate --lint          # Verifica el template
sam build                    # Compila la función
sam local invoke             # (Opcional) prueba local con Docker
sam deploy --guided          # Despliega a AWS
```

---

## Otra forma de invocar: `curl ... | bash`

Es posible servir el script desde una URL y ejecutarlo directamente:

```bash
curl -sSL https://dominio.com/new-lambda.sh | bash -s -- procesar-pagos ./funciones
```

`bash -s --` pasa todo lo que sigue como argumentos posicionales al script
recibido por stdin (aquí: `lambda_name=procesar-pagos`, `directorio_destino=./funciones`).

### ⚠️ Advertencia de seguridad (importante en entornos /regulados)

Este patrón **ejecuta código remoto sin inspección previa**. Si el endpoint se
ve comprometido (host vulnerado, ataque MITM, o typosquatting del dominio),
estarás corriendo código arbitrario con los permisos de tu usuario. En un
contexto regulado esto suele chocar con políticas de
control de cambios e integridad de software.

**Alternativa recomendada — descargar, revisar, ejecutar:**

```bash
curl -sSL https://dominio.com/new-lambda.sh -o new-lambda.sh
less new-lambda.sh          # Inspecciona el contenido
chmod +x new-lambda.sh
./new-lambda.sh procesar-pagos
```

**Alternativa con verificación de integridad (checksum):**

```bash
curl -sSL https://dominio.com/new-lambda.sh -o new-lambda.sh
echo "<sha256_esperado>  new-lambda.sh" | sha256sum -c -   # Aborta si no coincide
chmod +x new-lambda.sh
./new-lambda.sh procesar-pagos
```

Si decides exponer el script por HTTP, sírvelo siempre por **HTTPS válido**,
publica el `sha256sum` esperado junto al binario, y considera fijar una versión
inmutable (por ejemplo, una URL con tag/commit en lugar de `latest`).

---

## Solución de problemas

| Síntoma                                                       | Causa probable                          | Solución                                                       |
| ------------------------------------------------------------- | --------------------------------------- | -------------------------------------------------------------- |
| `'python3.13' is not one of [...]` en `sam validate --lint`   | SAM CLI < 1.131                         | Actualiza: `pip install --upgrade aws-sam-cli`                 |
| `Runtime.ImportModuleError: Unable to import module`          | `Handler` no coincide con archivo/función | Verifica que sea `lambda_function.lambda_handler`              |
| `Error: '<nombre>' ya existe`                                 | La carpeta destino ya existe            | Usa otro nombre o elimina/renombra la carpeta previa           |
| `'<nombre>' no es un nombre válido`                           | Nombre con caracteres no permitidos     | Usa solo letras, números, `-` y `_`, iniciando con letra       |
| El script no corre (`Permission denied`)                      | Falta el bit de ejecución               | `chmod +x new-lambda.sh`                                        |

---

## Extensiones sugeridas

Para escalar el generador conforme crezcan las necesidades del equipo:

- **Flags configurables:** `--runtime`, `--arch`, `--timeout`, `--memory` para no
  fijar valores por convención única.
- **Artefactos adicionales:** generar `requirements.txt` y `.gitignore` vacíos por defecto.
- **Migrar a `cookiecutter` o `sam init --location`:** si se manejan múltiples tipos
  de función (API, evento S3, cron, etc.), un sistema de plantillas con variables es
  más mantenible que un script bash.
