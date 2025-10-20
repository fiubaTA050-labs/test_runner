#!/bin/bash

# Script para ejecutar tests automáticos en todos los submissions (versión paralelizada)
# Uso: ./run_tests.sh <directorio_raiz> <fecha_limite> <filtro_test> <max_procesos>
# Ejemplo: ./run_tests.sh 2025b-tp2-submissions 2025-10-20 2A 4

set -e

# Verificar parámetros
if [ $# -ne 4 ]; then
    echo "Error: Se requieren 4 parámetros"
    echo "Uso: $0 <directorio_raiz> <fecha_limite> <filtro_test> <max_procesos>"
    echo "Ejemplo: $0 2025b-tp2-submissions 2025-10-20 2A 4"
    exit 1
fi

ROOT_DIRECTORY="$1"
DEADLINE_DATE="$2"
TEST_FILTER="$3"
MAX_PROCESSES="$4"

# Validar número de procesos
if ! [[ "$MAX_PROCESSES" =~ ^[0-9]+$ ]] || [ "$MAX_PROCESSES" -lt 1 ]; then
    echo "Error: max_procesos debe ser un número positivo"
    exit 1
fi

# Validar formato de fecha (YYYY-MM-DD)
if ! [[ $DEADLINE_DATE =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "Error: La fecha debe estar en formato YYYY-MM-DD"
    echo "Ejemplo: 2025-10-20"
    exit 1
fi

# Verificar que el directorio raíz existe
if [ ! -d "$ROOT_DIRECTORY" ]; then
    echo "Error: El directorio raíz '$ROOT_DIRECTORY' no existe"
    exit 1
fi

# Verificar que el script test_submission.sh existe
SCRIPT_DIR="$(dirname "$0")"
TEST_SCRIPT="$SCRIPT_DIR/test_submission.sh"

if [ ! -f "$TEST_SCRIPT" ]; then
    echo "Error: No se encontró el script test_submission.sh en $SCRIPT_DIR"
    echo "Asegúrate de que test_submission.sh esté en el mismo directorio que este script"
    exit 1
fi

# Hacer el script ejecutable si no lo es
if [ ! -x "$TEST_SCRIPT" ]; then
    chmod +x "$TEST_SCRIPT"
fi

echo "=== Ejecutando tests en todos los submissions (PARALELIZADO) ==="
echo "Directorio raíz: $ROOT_DIRECTORY"
echo "Fecha límite: $DEADLINE_DATE"
echo "Filtro de test: $TEST_FILTER"
echo "Script de test: $TEST_SCRIPT"
echo "Máximo de procesos paralelos: $MAX_PROCESSES"
echo ""

# Crear directorio temporal para archivos de resultados
TEMP_DIR=$(mktemp -d)
RESULTS_DIR="$TEMP_DIR/results"
mkdir -p "$RESULTS_DIR"

# Función para ejecutar tests en una submission específica
run_test_submission() {
    local submission_dir="$1"
    local submission_name="$2"
    local result_file="$RESULTS_DIR/${submission_name}.result"
    
    # Verificar que es un repositorio git
    if [ ! -d "$submission_dir/.git" ]; then
        echo "SKIPPED" > "$result_file"
        echo "No es un repositorio git" >> "$result_file"
        return 0
    fi
    
    # Ejecutar el script de test y capturar resultado
    if output=$("$TEST_SCRIPT" "$submission_dir" "$DEADLINE_DATE" "$TEST_FILTER" 2>&1); then
        echo "SUCCESS" > "$result_file"
        echo "$output" >> "$result_file"
        
        # Contar tests ejecutados y pasados para submissions exitosas
        total_tests=$(echo "$output" | grep -E "Test.*\(.*\):" | wc -l)
        passed_tests=$(echo "$output" | grep -E "\.\.\. Passed" | wc -l)
        failed_count=$(echo "$output" | grep -E "\-\-\- FAIL:" | wc -l)
        
        echo "TEST_COUNTS:" >> "$result_file"
        echo "Total: $total_tests" >> "$result_file"
        echo "Passed: $passed_tests" >> "$result_file"
        echo "Failed: $failed_count" >> "$result_file"
    else
        echo "FAILED" > "$result_file"
        echo "$output" >> "$result_file"
        
        # Extraer información específica de los tests que fallaron en formato sintético
        failed_tests=$(echo "$output" | grep -E "\-\-\- FAIL:" | head -10)
        if [ -n "$failed_tests" ]; then
            echo "FAILED_TESTS:" >> "$result_file"
            echo "$failed_tests" >> "$result_file"
        fi
        
        # Contar tests ejecutados y pasados
        total_tests=$(echo "$output" | grep -E "Test.*\(.*\):" | wc -l)
        passed_tests=$(echo "$output" | grep -E "\.\.\. Passed" | wc -l)
        failed_count=$(echo "$output" | grep -E "\-\-\- FAIL:" | wc -l)
        
        echo "TEST_COUNTS:" >> "$result_file"
        echo "Total: $total_tests" >> "$result_file"
        echo "Passed: $passed_tests" >> "$result_file"
        echo "Failed: $failed_count" >> "$result_file"
    fi
}

# Buscar todos los subdirectorios que contengan submissions
echo "Buscando submissions en $ROOT_DIRECTORY..."
echo ""

# Array para almacenar submissions válidas
declare -a SUBMISSION_DIRS=()
declare -a SUBMISSION_NAMES=()

# Recopilar todas las submissions válidas
for submission_dir in "$ROOT_DIRECTORY"/*; do
    # Verificar que es un directorio
    if [ ! -d "$submission_dir" ]; then
        continue
    fi
    
    # Obtener solo el nombre del directorio (sin la ruta completa)
    submission_name=$(basename "$submission_dir")
    
    # Saltar si no parece ser una submission (no contiene tp2)
    if [[ ! "$submission_name" =~ tp2 ]]; then
        continue
    fi
    
    SUBMISSION_DIRS+=("$submission_dir")
    SUBMISSION_NAMES+=("$submission_name")
done

TOTAL_SUBMISSIONS=${#SUBMISSION_DIRS[@]}

if [ $TOTAL_SUBMISSIONS -eq 0 ]; then
    echo "No se encontraron submissions válidas en $ROOT_DIRECTORY"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo "Encontradas $TOTAL_SUBMISSIONS submissions"
echo "Ejecutando tests en paralelo (máximo $MAX_PROCESSES procesos simultáneos)..."
echo ""

# Ejecutar tests en paralelo usando GNU parallel si está disponible, sino usar jobs en background
if command -v parallel >/dev/null 2>&1; then
    echo "Usando GNU parallel para máxima eficiencia..."
    
    # Crear archivo temporal con comandos
    COMMANDS_FILE="$TEMP_DIR/commands.txt"
    for i in "${!SUBMISSION_DIRS[@]}"; do
        submission_dir="${SUBMISSION_DIRS[$i]}"
        submission_name="${SUBMISSION_NAMES[$i]}"
        echo "run_test_submission '$submission_dir' '$submission_name'" >> "$COMMANDS_FILE"
    done
    
    # Ejecutar con parallel
    parallel -j "$MAX_PROCESSES" --line-buffer < "$COMMANDS_FILE"
else
    echo "Usando jobs en background (GNU parallel no disponible)..."
    
    # Ejecutar tests en lotes para evitar demasiados procesos simultáneos
    batch_size=$MAX_PROCESSES
    total_batches=$(( (TOTAL_SUBMISSIONS + batch_size - 1) / batch_size ))
    
    for batch in $(seq 0 $((total_batches - 1))); do
        start_idx=$((batch * batch_size))
        end_idx=$((start_idx + batch_size - 1))
        if [ $end_idx -ge $TOTAL_SUBMISSIONS ]; then
            end_idx=$((TOTAL_SUBMISSIONS - 1))
        fi
        
        echo "Ejecutando lote $((batch + 1))/$total_batches (submissions $((start_idx + 1))-$((end_idx + 1)))..."
        
        # Iniciar trabajos en este lote
        pids=()
        for i in $(seq $start_idx $end_idx); do
            submission_dir="${SUBMISSION_DIRS[$i]}"
            submission_name="${SUBMISSION_NAMES[$i]}"
            
            echo "🚀 Iniciando tests para: $submission_name"
            run_test_submission "$submission_dir" "$submission_name" &
            pids+=($!)
        done
        
        # Esperar a que terminen todos los trabajos de este lote
        for pid in "${pids[@]}"; do
            wait "$pid"
        done
        
        echo "Lote $((batch + 1)) completado."
    done
fi

echo ""
echo "Todos los tests han terminado. Procesando resultados..."
echo ""

# Procesar resultados
SUCCESSFUL_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

declare -a SUCCESSFUL_SUBMISSIONS=()
declare -a FAILED_SUBMISSIONS=()
declare -a SKIPPED_SUBMISSIONS=()
declare -a FAILED_TESTS_DETAILS=()
declare -a ALL_SUBMISSIONS_INFO=()

for submission_name in "${SUBMISSION_NAMES[@]}"; do
    result_file="$RESULTS_DIR/${submission_name}.result"
    
    if [ ! -f "$result_file" ]; then
        echo "⚠️  No se encontró archivo de resultado para: $submission_name"
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
        SKIPPED_SUBMISSIONS+=("$submission_name (sin resultado)")
        ALL_SUBMISSIONS_INFO+=("$submission_name: SKIPPED: Sin resultado")
        continue
    fi
    
    # Leer el estado del archivo de resultado
    status=$(head -n 1 "$result_file" 2>/dev/null || echo "UNKNOWN")
    
    # Obtener conteos de tests directamente de la salida
    total_tests=$(grep -E "Test.*\(.*\):" "$result_file" 2>/dev/null | wc -l | tr -d ' ')
    passed_tests=$(grep -E "\.\.\. Passed" "$result_file" 2>/dev/null | wc -l | tr -d ' ')
    failed_count=$(grep -E "\-\-\- FAIL:" "$result_file" 2>/dev/null | wc -l | tr -d ' ')
    
    # Asegurar que los valores sean números válidos
    total_tests=${total_tests:-0}
    passed_tests=${passed_tests:-0}
    failed_count=${failed_count:-0}
    
    # Calcular porcentaje
    if [ "$total_tests" -gt 0 ] 2>/dev/null; then
        percentage=$((passed_tests * 100 / total_tests))
    else
        percentage=0
    fi
    
    case "$status" in
        "SUCCESS")
            SUCCESS_TESTS=$((SUCCESS_TESTS + 1))
            SUCCESS_SUBMISSIONS+=("$submission_name")
            ALL_SUBMISSIONS_INFO+=("$submission_name: SUCCESS: ($passed_tests/$total_tests) ${percentage}%")
            echo "✅ ÉXITO: $submission_name ($passed_tests/$total_tests) ${percentage}%"
            ;;
        "FAILED")
            FAILED_TESTS=$((FAILED_TESTS + 1))
            FAILED_SUBMISSIONS+=("$submission_name")
            ALL_SUBMISSIONS_INFO+=("$submission_name: FAILED: ($passed_tests/$total_tests) ${percentage}%")
            echo "❌ FALLO: $submission_name ($passed_tests/$total_tests) ${percentage}%"
            
            # Extraer detalles de tests fallidos en formato sintético
            failed_tests=$(grep -E "\-\-\- FAIL:" "$result_file" 2>/dev/null | sort -u | head -10)
            if [ -n "$failed_tests" ]; then
                FAILED_TESTS_DETAILS+=("$submission_name:$failed_tests")
            fi
            ;;
        "SKIPPED")
            SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
            SKIPPED_SUBMISSIONS+=("$submission_name (no es git)")
            ALL_SUBMISSIONS_INFO+=("$submission_name: SKIPPED: No es git")
            echo "⚠️  SALTADO: $submission_name"
            ;;
        *)
            echo "⚠️  Estado desconocido para $submission_name: $status"
            SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
            SKIPPED_SUBMISSIONS+=("$submission_name (estado: $status)")
            ALL_SUBMISSIONS_INFO+=("$submission_name: UNKNOWN: $status")
            ;;
    esac
done

# Mostrar resumen final
echo "=========================================="
echo "RESUMEN FINAL"
echo "=========================================="
echo "Total de submissions encontradas: $TOTAL_SUBMISSIONS"
echo "Tests exitosos: $SUCCESS_TESTS"
echo "Tests fallidos: $FAILED_TESTS"
echo "Tests saltados: $SKIPPED_TESTS"
echo ""

# Mostrar todas las submissions con sus estadísticas
echo "📊 TODAS LAS SUBMISSIONS:"
for submission_info in "${ALL_SUBMISSIONS_INFO[@]}"; do
    submission_name="${submission_info%%:*}"
    status_info="${submission_info#*:}"
    status="${status_info%%:*}"
    status="${status# }"  # Eliminar espacio inicial
    stats="${status_info#*:}"
    
    # Debug: mostrar el parsing (comentado)
    # echo "DEBUG: submission_info='$submission_info'"
    # echo "DEBUG: submission_name='$submission_name'"
    # echo "DEBUG: status_info='$status_info'"
    # echo "DEBUG: status='$status'"
    # echo "DEBUG: stats='$stats'"
    
    case "$status" in
        "SUCCESS")
            echo "   ✅ $submission_name $stats"
            ;;
        "FAILED")
            echo "   ❌ $submission_name $stats"
            ;;
        "SKIPPED")
            echo "   ⚠️  $submission_name $stats"
            ;;
        *)
            echo "   ❓ $submission_name $stats"
            ;;
    esac
done
echo ""

# Mostrar detalles específicos de fallos
if [ ${#FAILED_SUBMISSIONS[@]} -gt 0 ]; then
    echo "❌ DETALLES DE SUBMISSIONS FALLIDAS:"
    for submission in "${FAILED_SUBMISSIONS[@]}"; do
        echo "   $submission:"
        
        # Buscar detalles para esta submission
        for detail_entry in "${FAILED_TESTS_DETAILS[@]}"; do
            if [[ "$detail_entry" == "$submission:"* ]]; then
                details="${detail_entry#$submission:}"
                echo "$details" | while IFS= read -r line; do
                    if [ -n "$line" ]; then
                        echo "     $line"
                    fi
                done
                break
            fi
        done
        echo ""
    done
fi

# Calcular porcentaje de éxito
if [ $TOTAL_SUBMISSIONS -gt 0 ]; then
    SUCCESS_PERCENTAGE=$((SUCCESS_TESTS * 100 / TOTAL_SUBMISSIONS))
    echo "Porcentaje de éxito: $SUCCESS_PERCENTAGE%"
fi

echo ""
echo "=== Ejecución completada ==="

# Limpiar directorio temporal
rm -rf "$TEMP_DIR"

# Salir con código de error si hay fallos
if [ $FAILED_TESTS -gt 0 ]; then
    exit 1
else
    exit 0
fi
