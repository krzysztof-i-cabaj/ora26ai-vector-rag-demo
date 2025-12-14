/* * ======================================================================================
 * SCRIPT: 07_semantic_clustering.sql
 * AUTHOR: KCB Kris & AI Assistant
 * PL: Analiza klastrów semantycznych - grupowanie zgłoszeń po znaczeniu tekstowym
 * EN: Semantic clustering analysis - grouping tickets by textual meaning
 * ======================================================================================
 * 
 * LOGIKA / LOGIC:
 * ---------------
 * PL: 1. Znajdujemy centroidy departamentów (średnie wektory)
 *     2. Dla każdego zgłoszenia obliczamy odległość do WSZYSTKICH centroidów
 *     3. Porównujemy klasyfikację rzeczywistą (department) z najbliższym centroidem
 *     4. Zgłoszenia, których najbliższy centroid nie zgadza się z departamentem = źle klasyfikowane
 *     5. Wizualizujemy macierz podobieństwa i klastry
 *
 * EN: 1. Find department centroids (average vectors)
 *     2. For each ticket, calculate distance to ALL centroids
 *     3. Compare actual classification (department) with closest centroid
 *     4. Tickets where closest centroid ≠ department = misclassified
 *     5. Visualize similarity matrix and clusters
 * ======================================================================================
 */

SET SERVEROUTPUT ON
SET LINESIZE 200
SET PAGESIZE 100

PROMPT ========================================
PROMPT   ORACLE VECTOR - SEMANTIC CLUSTERING
PROMPT   Analiza klastrów semantycznych / Semantic Clustering Analysis
PROMPT ========================================
PROMPT

-- ======================================================================================
-- CZĘŚĆ 1: Obliczenie centroidów departamentów
-- PART 1: Department centroid calculation
-- ======================================================================================

PROMPT [STEP 1] Obliczanie centroidów dla każdego departamentu...
PROMPT [STEP 1] Calculating centroids for each department...
PROMPT

WITH dept_centroids AS (
    SELECT 
        department,
        COUNT(*) as ticket_count,
        TO_VECTOR(
            (SELECT AVG(TO_VECTOR(t2.embedding)) 
             FROM galactic_tickets t2 
             WHERE t2.department = department
             AND t2.embedding IS NOT NULL),
            384, FLOAT32
        ) as centroid
    FROM galactic_tickets
    WHERE embedding IS NOT NULL
    GROUP BY department
)
SELECT 
    department,
    ticket_count
FROM dept_centroids
ORDER BY department;

PROMPT
PROMPT [STEP 2] Macierz podobieństwa między departamentami...
PROMPT [STEP 2] Similarity matrix between departments...
PROMPT

-- ======================================================================================
-- CZĘŚĆ 2: Macierz dystansów między centroidami departamentów
-- PART 2: Distance matrix between department centroids
-- ======================================================================================

WITH dept_centroids AS (
    SELECT 
        department,
        TO_VECTOR(
            (SELECT AVG(TO_VECTOR(t2.embedding)) 
             FROM galactic_tickets t2 
             WHERE t2.department = department
             AND t2.embedding IS NOT NULL),
            384, FLOAT32
        ) as centroid
    FROM galactic_tickets
    WHERE embedding IS NOT NULL
    GROUP BY department
)
SELECT 
    d1.department as dept_1,
    d2.department as dept_2,
    ROUND(VECTOR_DISTANCE(d1.centroid, d2.centroid, COSINE), 4) as cosine_distance
FROM dept_centroids d1
CROSS JOIN dept_centroids d2
WHERE d1.department <= d2.department
ORDER BY d1.department, d2.department;

PROMPT
PROMPT [STEP 3] Klasyfikacja zgłoszeń: rzeczywista vs. semantyczna...
PROMPT [STEP 3] Ticket classification: actual vs. semantic...
PROMPT

-- ======================================================================================
-- CZĘŚĆ 3: Identyfikacja źle sklasyfikowanych zgłoszeń
-- PART 3: Identifying misclassified tickets
-- ======================================================================================

WITH dept_centroids AS (
    SELECT 
        department,
        TO_VECTOR(
            (SELECT AVG(TO_VECTOR(t2.embedding)) 
             FROM galactic_tickets t2 
             WHERE t2.department = department
             AND t2.embedding IS NOT NULL),
            384, FLOAT32
        ) as centroid
    FROM galactic_tickets
    WHERE embedding IS NOT NULL
    GROUP BY department
),
ticket_distances_to_all AS (
    SELECT 
        t.ticket_id,
        t.department as actual_dept,
        t.severity,
        t.description,
        dc.department as centroid_dept,
        ROUND(VECTOR_DISTANCE(t.embedding, dc.centroid, COSINE), 4) as distance,
        ROW_NUMBER() OVER (
            PARTITION BY t.ticket_id 
            ORDER BY VECTOR_DISTANCE(t.embedding, dc.centroid, COSINE) ASC
        ) as rank
    FROM galactic_tickets t
    CROSS JOIN dept_centroids dc
    WHERE t.embedding IS NOT NULL
),
closest_centroid AS (
    SELECT 
        ticket_id,
        actual_dept,
        severity,
        description,
        centroid_dept as closest_centroid,
        distance,
        CASE 
            WHEN actual_dept = centroid_dept THEN '✓ Poprawna / Correct'
            ELSE '✗ Źle klasyfikowana / Misclassified'
        END as classification_status
    FROM ticket_distances_to_all
    WHERE rank = 1
)
SELECT 
    ticket_id,
    actual_dept,
    closest_centroid,
    severity,
    ROUND(distance, 4) as distance_to_closest,
    classification_status,
    description
FROM closest_centroid
ORDER BY 
    CASE WHEN classification_status LIKE 'Misclassified%' THEN 0 ELSE 1 END,
    distance DESC;

PROMPT
PROMPT [STEP 4] Statystyka błędnej klasyfikacji...
PROMPT [STEP 4] Misclassification statistics...
PROMPT

-- ======================================================================================
-- CZĘŚĆ 4: Podsumowanie statystyczne
-- PART 4: Statistical summary
-- ======================================================================================

WITH dept_centroids AS (
    SELECT 
        department,
        TO_VECTOR(
            (SELECT AVG(TO_VECTOR(t2.embedding)) 
             FROM galactic_tickets t2 
             WHERE t2.department = department
             AND t2.embedding IS NOT NULL),
            384, FLOAT32
        ) as centroid
    FROM galactic_tickets
    WHERE embedding IS NOT NULL
    GROUP BY department
),
ticket_distances_to_all AS (
    SELECT 
        t.ticket_id,
        t.department as actual_dept,
        dc.department as centroid_dept,
        VECTOR_DISTANCE(t.embedding, dc.centroid, COSINE) as distance,
        ROW_NUMBER() OVER (
            PARTITION BY t.ticket_id 
            ORDER BY VECTOR_DISTANCE(t.embedding, dc.centroid, COSINE) ASC
        ) as rank
    FROM galactic_tickets t
    CROSS JOIN dept_centroids dc
    WHERE t.embedding IS NOT NULL
),
closest_centroid AS (
    SELECT 
        ticket_id,
        actual_dept,
        centroid_dept,
        distance,
        CASE 
            WHEN actual_dept = centroid_dept THEN 1
            ELSE 0
        END as is_correct
    FROM ticket_distances_to_all
    WHERE rank = 1
)
SELECT 
    actual_dept as department,
    COUNT(*) as total_tickets,
    SUM(is_correct) as correctly_classified,
    COUNT(*) - SUM(is_correct) as misclassified,
    ROUND(100.0 * SUM(is_correct) / COUNT(*), 1) as accuracy_pct,
    ROUND(AVG(distance), 4) as avg_distance_to_closest
FROM closest_centroid
GROUP BY actual_dept
ORDER BY accuracy_pct ASC;

PROMPT
PROMPT ========================================
PROMPT   ANALIZA KLASTRÓW ZAKOŃCZONA / CLUSTERING ANALYSIS COMPLETE
PROMPT ========================================
