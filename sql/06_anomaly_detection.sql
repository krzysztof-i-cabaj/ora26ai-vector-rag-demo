/* * ======================================================================================
 * SCRIPT: 06_anomaly_detection.sql
 * AUTHOR: KCB Kris & AI Assistant
 * PL: Wykrywanie anomalii - zgłoszenia "błędnie sklasyfikowane" w swoim departamencie
 * EN: Anomaly Detection - "misclassified" tickets within their department
 * ======================================================================================
 * 
 * LOGIKA / LOGIC:
 * ---------------
 * 1. Dla każdego departamentu obliczamy CENTROID (średni wektor wszystkich zgłoszeń)
 * 2. Dla każdego zgłoszenia obliczamy odległość COSINE od centroidu własnego departamentu
 * 3. Obliczamy statystyki: średnią odległość i odchylenie standardowe
 * 4. Zgłoszenia z odległością > średnia + 1*stddev uznajemy za ANOMALIE
 *
 * INTERPRETACJA / INTERPRETATION:
 * ------------------------------
 * - Wysoka odległość = zgłoszenie semantycznie różne od typowych w swoim dziale
 * - Może oznaczać błędną klasyfikację lub wyjątkowy przypadek
 * - Przydatne do weryfikacji jakości danych lub wykrywania nietypowych sytuacji
 * ======================================================================================
 */

SET SERVEROUTPUT ON
SET LINESIZE 200
SET PAGESIZE 100

PROMPT ========================================
PROMPT   ORACLE VECTOR - ANOMALY DETECTION
PROMPT ========================================
PROMPT

-- ======================================================================================
-- CZĘŚĆ 1: Analiza statystyczna rozkładu odległości
-- ======================================================================================

PROMPT [STEP 1] Obliczanie statystyk odległości dla każdego departamentu...
PROMPT

WITH dept_stats AS (
    SELECT 
        t1.department,
        ROUND(AVG(
            VECTOR_DISTANCE(
                t1.embedding, 
                TO_VECTOR(
                    (SELECT AVG(TO_VECTOR(t2.embedding)) 
                     FROM galactic_tickets t2 
                     WHERE t2.department = t1.department 
                     AND t2.embedding IS NOT NULL),
                    384, FLOAT32
                ),
                COSINE
            )
        ), 4) as avg_distance,
        ROUND(STDDEV(
            VECTOR_DISTANCE(
                t1.embedding, 
                TO_VECTOR(
                    (SELECT AVG(TO_VECTOR(t2.embedding)) 
                     FROM galactic_tickets t2 
                     WHERE t2.department = t1.department 
                     AND t2.embedding IS NOT NULL),
                    384, FLOAT32
                ),
                COSINE
            )
        ), 4) as stddev_distance,
        COUNT(*) as ticket_count
    FROM galactic_tickets t1
    WHERE t1.embedding IS NOT NULL
    GROUP BY t1.department
)
SELECT 
    department,
    ticket_count,
    avg_distance,
    stddev_distance,
    ROUND(avg_distance + stddev_distance, 4) as anomaly_threshold
FROM dept_stats
ORDER BY department;

PROMPT
PROMPT [STEP 2] Wykrywanie anomalii - zgłoszenia z dużą odległością od centroidu...
PROMPT

-- ======================================================================================
-- CZĘŚĆ 2: Identyfikacja zgłoszeń anomalnych
-- ======================================================================================

WITH ticket_distances AS (
    SELECT 
        t1.ticket_id,
        t1.department,
        t1.severity,
        t1.description,
        ROUND(
            VECTOR_DISTANCE(
                t1.embedding, 
                TO_VECTOR(
                    (SELECT AVG(TO_VECTOR(t2.embedding)) 
                     FROM galactic_tickets t2 
                     WHERE t2.department = t1.department 
                     AND t2.embedding IS NOT NULL),
                    384, FLOAT32
                ),
                COSINE
            ), 
            4
        ) as dist_from_centroid
    FROM galactic_tickets t1
    WHERE t1.embedding IS NOT NULL
),
global_stats AS (
    SELECT 
        AVG(dist_from_centroid) as global_avg,
        STDDEV(dist_from_centroid) as global_stddev
    FROM ticket_distances
)
SELECT 
    td.ticket_id,
    td.department,
    td.severity,
    td.description,
    td.dist_from_centroid as distance,
    gs.global_avg as avg_global,
    CASE 
        WHEN td.dist_from_centroid > gs.global_avg + 1.5 * gs.global_stddev 
        THEN '🔴 CRITICAL'
        WHEN td.dist_from_centroid > gs.global_avg + gs.global_stddev
        THEN '🟡 MODERATE'
        ELSE '🟢 MINOR'
    END as anomaly_level,
    ROUND(
        ((td.dist_from_centroid - gs.global_avg) / gs.global_stddev), 
        2
    ) as z_score
FROM ticket_distances td, global_stats gs
WHERE td.dist_from_centroid > gs.global_avg
ORDER BY td.dist_from_centroid DESC
FETCH FIRST 20 ROWS ONLY;

PROMPT
PROMPT [STEP 3] Top 5 najbardziej "nietypowych" zgłoszeń w każdym departamencie...
PROMPT

-- ======================================================================================
-- CZĘŚĆ 3: Top anomalie w każdym departamencie osobno
-- ======================================================================================

WITH dept_distances AS (
    SELECT 
        t1.ticket_id,
        t1.department,
        t1.severity,
        t1.description,
        ROUND(
            VECTOR_DISTANCE(
                t1.embedding, 
                TO_VECTOR(
                    (SELECT AVG(TO_VECTOR(t2.embedding)) 
                     FROM galactic_tickets t2 
                     WHERE t2.department = t1.department 
                     AND t2.embedding IS NOT NULL),
                    384, FLOAT32
                ),
                COSINE
            ), 
            4
        ) as distance,
        ROW_NUMBER() OVER (
            PARTITION BY t1.department 
            ORDER BY VECTOR_DISTANCE(
                t1.embedding, 
                TO_VECTOR(
                    (SELECT AVG(TO_VECTOR(t2.embedding)) 
                     FROM galactic_tickets t2 
                     WHERE t2.department = t1.department 
                     AND t2.embedding IS NOT NULL),
                    384, FLOAT32
                ),
                COSINE
            ) DESC
        ) as rank_in_dept
    FROM galactic_tickets t1
    WHERE t1.embedding IS NOT NULL
)
SELECT 
    department,
    rank_in_dept as rank,
    ticket_id,
    severity,
    distance,
    description
FROM dept_distances
WHERE rank_in_dept <= 5
ORDER BY department, rank_in_dept;

PROMPT
PROMPT ========================================
PROMPT   ANALIZA ZAKOŃCZONA
PROMPT ========================================
