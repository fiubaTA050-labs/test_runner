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
./test_submission.sh 2025b-tp2-submissions/2025b-tp2-alendavies 2025-10-20 2A
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

## Características Principales

### ⚡ **Paralelización**
- Ejecuta múltiples tests simultáneamente
- Configurable con `max_procesos`
- Compatible con sistemas sin GNU parallel

### ⏱️ **Timeout Automático**
- Límite de 10 minutos por submission
- Evita tests colgados
- Compatible con macOS y Linux

### 📊 **Análisis Detallado**
- Conteo de tests ejecutados vs pasados: `(3/3) 100%`
- Lista de tests fallidos con tiempo: `--- FAIL: TestName (4.5s)`
- Resumen organizado por estado (exitosos/fallidos)

### 🔄 **Gestión de Git**
- Checkout automático al último commit antes de la fecha límite
- Restauración de archivos no modificables a su versión original
- Sincronización con repositorio remoto

## Ejemplo de Salida

```bash
=== Ejecutando tests en todos los submissions (PARALELIZADO) ===
Encontradas 18 submissions
Ejecutando tests en paralelo (máximo 10 procesos simultáneos)...

✅ ÉXITO: 2025b-tp2-alendavies (3/3) 100%
❌ FALLO: 2025b-tp2-FrancoCorn (1/3) 33%
✅ ÉXITO: 2025b-tp2-LetiAab (3/3) 100%

==========================================
RESUMEN FINAL
==========================================
Total de submissions encontradas: 18
Tests exitosos: 16
Tests fallidos: 2

📊 TODAS LAS SUBMISSIONS:
   ✅ 2025b-tp2-alendavies  (3/3) 100%
   ❌ 2025b-tp2-FrancoCorn  (1/3) 33%
   ✅ 2025b-tp2-LetiAab  (3/3) 100%

❌ DETALLES DE SUBMISSIONS FALLIDAS:
   2025b-tp2-FrancoCorn:
     --- FAIL: TestInitialElection2A (4.89s)
     --- FAIL: TestReElection2A (4.93s)

Porcentaje de éxito: 88%
```

## Archivos No Modificables

Los scripts restauran automáticamente estos archivos a su versión original:
- `src/raft/config.go`
- `src/raft/persister.go`
- `src/raft/test_test.go`

## Requisitos

- Bash 4.0+
- Git
- Go
- `timeout` o `gtimeout` (opcional, tiene fallback)

## Notas

- Los scripts crean directorios temporales que se limpian automáticamente
- El código de salida es 1 si hay submissions fallidas
- Compatible con macOS y Linux
- Los tests tienen timeout de 10 minutos por defecto
