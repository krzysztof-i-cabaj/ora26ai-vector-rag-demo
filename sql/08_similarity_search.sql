/* =====================================================================================
 * SCRIPT: 08_similarity_search.sql
 * AUTHOR: KCB / AI Assistant
 * PL: Analiza podobieństwa między wszystkimi zgłoszeniami (pairwise cosine distance)
 * EN: Similarity analysis across all tickets (pairwise cosine distance)
 *
 * ZASTOSOWANIE / USAGE:
 * - Dostarcza wyników wykorzystywanych w Scenario B (similarity search) na stronach HTML.
 * - Obejmuje: agregaty globalne, top najbardziej podobnych par, statystyki intra- i międzydziałowe.
 *
 * WYMAGANIA / REQUIREMENTS:
 * - Tabela: GALACTIC_TICKETS z kolumnami TICKET_ID (PK), DEPARTMENT, EMBEDDING (VECTOR(384,FLOAT32)).
 * - Oracle 23ai z operatorem VECTOR_DISTANCE(..., COSINE).
 * ===================================================================================== */

SET SERVEROUTPUT ON
SET LINESIZE 200
SET PAGESIZE 200
SET TRIMSPOOL ON

PROMPT ========================================
PROMPT   SCENARIO B - SIMILARITY SEARCH
PROMPT ========================================
PROMPT

-- =====================================================================================
-- CZĘŚĆ 1 / PART 1: Agregaty globalne par (wszystkie kombinacje ticketów)
-- =====================================================================================
WITH pairs AS (
    SELECT VECTOR_DISTANCE(t1.embedding, t2.embedding, COSINE) AS dist
    FROM galactic_tickets t1
    JOIN galactic_tickets t2 ON t1.ticket_id < t2.ticket_id
    WHERE t1.embedding IS NOT NULL
      AND t2.embedding IS NOT NULL
)
SELECT
    COUNT(*)                                   AS total_pairs,
    ROUND(AVG(dist), 4)                        AS avg_distance,
    SUM(CASE WHEN dist < 0.15 THEN 1 END)      AS very_high,
    SUM(CASE WHEN dist >= 0.15 AND dist < 0.25 THEN 1 END) AS high,
    SUM(CASE WHEN dist >= 0.25 AND dist < 0.35 THEN 1 END) AS moderate,
    SUM(CASE WHEN dist >= 0.35 THEN 1 END)     AS low
FROM pairs;

PROMPT
PROMPT [STEP 2] Top 30 najbardziej podobnych par (najmniejszy dystans cosine)
PROMPT [STEP 2] Top 30 most similar pairs (smallest cosine distance)

WITH pairs AS (
    SELECT t1.ticket_id AS id1, t1.department AS dept1,
           t2.ticket_id AS id2, t2.department AS dept2,
           VECTOR_DISTANCE(t1.embedding, t2.embedding, COSINE) AS dist
    FROM galactic_tickets t1
    JOIN galactic_tickets t2 ON t1.ticket_id < t2.ticket_id
    WHERE t1.embedding IS NOT NULL
      AND t2.embedding IS NOT NULL
)
SELECT id1, id2, dept1, dept2,
       ROUND(dist, 4) AS distance,
       ROUND((1 - dist) * 100, 2) AS similarity_pct
FROM pairs
ORDER BY dist ASC
FETCH FIRST 30 ROWS ONLY;

PROMPT
PROMPT [STEP 3] Statystyki wewnątrz działów (intra-department)
PROMPT [STEP 3] Intra-department similarity stats

WITH pairs AS (
    SELECT t1.department AS dept1,
           t2.department AS dept2,
           VECTOR_DISTANCE(t1.embedding, t2.embedding, COSINE) AS dist
    FROM galactic_tickets t1
    JOIN galactic_tickets t2 ON t1.ticket_id < t2.ticket_id
    WHERE t1.embedding IS NOT NULL
      AND t2.embedding IS NOT NULL
)
SELECT dept1 AS department,
       COUNT(*) AS total_pairs,
       SUM(CASE WHEN dist < 0.15 THEN 1 END) AS very_high,
       ROUND(100 * SUM(CASE WHEN dist < 0.15 THEN 1 END) / COUNT(*), 1) AS pct_very_high,
       ROUND(AVG(dist), 4) AS avg_distance
FROM pairs
WHERE dept1 = dept2
GROUP BY dept1
ORDER BY dept1;

PROMPT
PROMPT [STEP 4] Statystyki między działami (cross-department)
PROMPT [STEP 4] Cross-department similarity stats

WITH pairs AS (
    SELECT t1.department AS dept1,
           t2.department AS dept2,
           VECTOR_DISTANCE(t1.embedding, t2.embedding, COSINE) AS dist
    FROM galactic_tickets t1
    JOIN galactic_tickets t2 ON t1.ticket_id < t2.ticket_id
    WHERE t1.embedding IS NOT NULL
      AND t2.embedding IS NOT NULL
)
SELECT dept1 || '  ' || dept2 AS dept_pair,
       COUNT(*) AS total_pairs,
       SUM(CASE WHEN dist < 0.15 THEN 1 END) AS very_high,
       ROUND(AVG(dist), 4) AS avg_distance
FROM pairs
WHERE dept1 < dept2
GROUP BY dept1, dept2
ORDER BY dept_pair;

PROMPT
PROMPT ========================================
PROMPT   SIMILARITY SEARCH DONE
PROMPT ========================================
