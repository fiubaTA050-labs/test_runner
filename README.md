# Scripts de Testing Automático para Trabajos Prácticos

Scripts para ejecutar tests automáticamente en submissions de estudiantes con paralelización y análisis detallado de resultados.

## Scripts Disponibles

### `test_submission.sh` - Test Individual
Ejecuta tests en una submission específica.

**Uso:**
```bash
./test_submission.sh <subdirectorio> <fecha_limite> <filtro_test>
```

**Parámetros:**
- `subdirectorio`: Ruta a la submission del estudiante
- `fecha_limite`: Fecha límite en formato YYYY-MM-DD
- `filtro_test`: Filtro para `go test -run` (ej: "2A", "3B")

**Ejemplo:**
```bash
./test_submission.sh 2025b-tp2-submissions/2025b-tp2-espinaemmanuel 2025-10-20 2A
```

### `run_tests.sh` - Tests Masivos Paralelos
Ejecuta tests en todas las submissions de un directorio en paralelo.

**Uso:**
```bash
./run_tests.sh <directorio_raiz> <fecha_limite> <filtro_test> <max_procesos>
```

**Parámetros:**
- `directorio_raiz`: Directorio con todas las submissions
- `fecha_limite`: Fecha límite en formato YYYY-MM-DD
- `filtro_test`: Filtro para `go test -run`
- `max_procesos`: Número máximo de procesos paralelos (obligatorio)

**Ejemplo:**
```bash
./run_tests.sh 2025b-tp2-submissions 2025-10-20 2A 10
```

## Archivos No Modificables

Los scripts restauran automáticamente estos archivos a su versión original:
- `src/raft/config.go`
- `src/raft/persister.go`
- `src/raft/test_test.go`
