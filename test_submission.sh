#!/bin/bash

# Script para ejecutar tests automáticos de trabajos enviados por estudiantes
# Uso: ./test_submission.sh <subdirectorio> <fecha_limite> <filtro_test> [branch]
# Ejemplo: ./test_submission.sh 2025b-tp2-submissions/2025b-tp2-alendavies 2025-10-20 3B
# Ejemplo con branch: ./test_submission.sh 2025b-tp2-submissions/2025b-tp2-alendavies 2025-10-20 3B develop

set -e  # Salir si cualquier comando falla

# Verificar que se proporcionaron los parámetros requeridos
if [ $# -lt 3 ] || [ $# -gt 4 ]; then
    echo "Error: Se requieren entre 3 y 4 parámetros"
    echo "Uso: $0 <subdirectorio> <fecha_limite> <filtro_test> [branch]"
    echo "Ejemplo: $0 2025b-tp2-submissions/2025b-tp2-alendavies 2025-10-20 3B"
    echo "Ejemplo con branch: $0 2025b-tp2-submissions/2025b-tp2-alendavies 2025-10-20 3B develop"
    exit 1
fi

SUBDIRECTORY="$1"
DEADLINE_DATE="$2"
TEST_FILTER="$3"
BRANCH="${4:-main}"  # Usar main como default si no se especifica

# Validar formato de fecha (YYYY-MM-DD)
if ! [[ $DEADLINE_DATE =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "Error: La fecha debe estar en formato YYYY-MM-DD"
    echo "Ejemplo: 2025-10-20"
    exit 1
fi

# Verificar que el subdirectorio existe
if [ ! -d "$SUBDIRECTORY" ]; then
    echo "Error: El subdirectorio '$SUBDIRECTORY' no existe"
    exit 1
fi

echo "=== Ejecutando tests para submission ==="
echo "Subdirectorio: $SUBDIRECTORY"
echo "Fecha límite: $DEADLINE_DATE"
echo "Filtro de test: $TEST_FILTER"
echo "Branch: $BRANCH"
echo ""

# Posicionarse en el directorio del test
cd "$SUBDIRECTORY"

echo "1. Posicionado en directorio: $(pwd)"

# Verificar que es un repositorio git
if [ ! -d ".git" ]; then
    echo "Error: El directorio no es un repositorio git"
    exit 1
fi

# Sincronizar con el remote
echo "2. Sincronizando con el remote..."
git fetch --all

# Verificar que el branch existe
echo "3. Verificando que el branch '$BRANCH' existe..."
if ! git show-ref --verify --quiet refs/heads/"$BRANCH" && ! git show-ref --verify --quiet refs/remotes/origin/"$BRANCH"; then
    echo "Error: El branch '$BRANCH' no existe localmente ni en el remote"
    exit 1
fi

# Descartar todos los cambios locales antes de cambiar de branch
echo "4. Descartando cambios locales para poder cambiar de branch..."
git reset --hard HEAD
git clean -fd

# Cambiar al branch especificado
echo "5. Cambiando al branch '$BRANCH'..."
git checkout "$BRANCH"

# Calcular la fecha límite en formato ISO (medianoche de la fecha especificada)
DEADLINE_ISO="${DEADLINE_DATE}T23:59:59"

echo "6. Buscando el último commit antes de la medianoche de $DEADLINE_DATE en el branch '$BRANCH'..."

# Encontrar el último commit antes de la fecha límite en el branch especificado
LAST_COMMIT=$(git log "$BRANCH" --before="$DEADLINE_ISO" --oneline -1 --format="%H" 2>/dev/null)

if [ -z "$LAST_COMMIT" ]; then
    echo "Error: No se encontró ningún commit antes de la fecha límite $DEADLINE_DATE"
    exit 1
fi

echo "   Último commit encontrado: $LAST_COMMIT"

# Hacer checkout del último commit antes de la fecha límite
echo "7. Haciendo checkout del commit $LAST_COMMIT..."
echo "   Branch actual: $BRANCH"
echo "   Fecha del commit: $(git log -1 --format='%ci' "$LAST_COMMIT")"
git checkout "$LAST_COMMIT"

# Verificar que los archivos no modificables existen
NON_MODIFIABLE_FILES=(
    "src/raft/config.go"
    "src/raft/persister.go"
    "src/raft/test_test.go"
)

echo "8. Verificando archivos no modificables..."
for file in "${NON_MODIFIABLE_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "Error: El archivo no modificable '$file' no existe"
        exit 1
    fi
done

# Hacer checkout de la primera versión de los archivos no modificables
echo "9. Restaurando archivos no modificables a su primera versión..."

# Obtener el primer commit del repositorio
FIRST_COMMIT=$(git rev-list --max-parents=0 HEAD 2>/dev/null | tail -1)

if [ -z "$FIRST_COMMIT" ]; then
    echo "Error: No se pudo encontrar el primer commit del repositorio"
    exit 1
fi

echo "   Primer commit del repositorio: $FIRST_COMMIT"

# Restaurar cada archivo no modificable desde el primer commit
for file in "${NON_MODIFIABLE_FILES[@]}"; do
    echo "   Restaurando $file desde el primer commit..."
    git checkout "$FIRST_COMMIT" -- "$file"
done

# Verificar que estamos en el directorio src/raft para ejecutar los tests
RAFT_DIR="src/raft"
if [ ! -d "$RAFT_DIR" ]; then
    echo "Error: El directorio '$RAFT_DIR' no existe"
    exit 1
fi


echo "10. Ejecutando tests con filtro '$TEST_FILTER'..."
cd "$RAFT_DIR"

# Ejecutar los tests con el filtro especificado
echo "   Comando: time go test -run $TEST_FILTER"
echo ""

# Ejecutar el test con time para medir el tiempo de ejecución
if time go test -run "$TEST_FILTER"; then
    echo ""
    echo "=== Tests completados exitosamente ==="
else
    exit_code=$?
    echo ""
    echo "=== ERROR: Tests fallaron con código de salida $exit_code ==="
    exit $exit_code
fi
